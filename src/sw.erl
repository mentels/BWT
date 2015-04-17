% Smith-Waterman algo
% for finding best local matching between two sequences
%
% http://en.wikipedia.org/wiki/Smith%E2%80%93Waterman_algorithm
%

-module(sw).
-export([
		t/1,
		sw/2,
		rand_seq/1]).

-define(MATCH,2).
-define(MISMATCH,-1).
-define(GAP_PENALTY,-2).
-define(GAP_EXT_PENALTY,-1).

-define(UNDEF,1).

-define(THRESHOLD, 40).



t(0) -> ok;
t(N) ->
	io:format("~p~n",[sw(30,30+?THRESHOLD)]),
	t(N-1).


rand_seq(N)->
	rand_seq([],N).
rand_seq(Acc,0) -> Acc;
rand_seq(Acc,N) -> 
	case random:uniform() < 0.1 of
		true ->
			rand_seq([lists:nth(random:uniform(10),[$Y,$R,$B,$D,$K,$M,$N,$S,$V,$W])|Acc], N-1);
		_ ->
			rand_seq([lists:nth(random:uniform(4),[$A,$C,$G,$T])|Acc], N-1)
	end.




sw([_|_]=Qseq,[_|_]=Ref) when length(Qseq) > length(Ref) -> no_match;
sw([_|_]=Qseq,[_|_]=Ref) ->
	io:format("Seq: ~p~n",[Qseq]),
	io:format("Ref: ~p~n",[Ref]),
	
	%%%%%% {Header,[column]}
	Tab0 = [ [{0,undef}] || _ <- lists:seq(0,length(Ref)) ],
	case build_tab(Tab0,Ref,Qseq,0,0) of
		low_score -> no_match;
		CIGAR -> CIGAR
	end;

sw(N1,N2) when N1 =< N2 -> 
	random:seed(),
	rand_seq(10),
	sw(rand_seq(N1),rand_seq(N2));
sw(_,_) -> no_match.



build_tab(_,_,_,V1max,Vpmax) when Vpmax-V1max >= ?THRESHOLD -> low_score;
build_tab(Tab,Ref,[S|Qseq],_,Vpmax) -> % Vs1, Vs2 - starting scores for the previous and curr rows
	%io:format("Vm:~p, Vpmax:~p~n",[V1max,Vpmax]),
	[[{V,Dir}|FirstCol]|Tab1] = Tab,
	V1 = case Vpmax of
		0 -> V+?GAP_PENALTY;
		_ -> V+?GAP_EXT_PENALTY
	end,
	{V2max,Tab2} = add_row2tab(Tab1,Ref,S,[[{V1,up},{V,Dir}|FirstCol]], V1), % Gap = Insertion
	build_tab(Tab2,Ref,Qseq,V2max,Vpmax+?MATCH);
build_tab(Tab,_,[],Vmax,_) -> 
	io:format("Tab:~n~p~n",[Tab]),
	get_CIGAR(Tab,Vmax).
	



add_row2tab([[{Vup,_}|_]=Col|Tab],[Sr|Ref], Sq, [[{Vleft,_},{Vul,_}|_]|_]=AccT, Vmax) ->
	
	{V,Dir} = lists:max([
		{Vul+sigma(Sq,Sr),up_left},
		{Vleft+?GAP_PENALTY,left},
		{Vup+?GAP_PENALTY,up} 
		]),
	%io:format("~n  Vul: ~p,\tVup: ~p~n",[Vul,Vup]),
	%io:format("Vleft: ~p,\tV: ~p\tSref: ~c, Sqsec: ~c  Dir: ~p~n",[Vleft,V,Sr,Sq,Dir]),
	
	add_row2tab(Tab,Ref,Sq,[[{V,Dir}|Col]|AccT], max(Vmax,V));

add_row2tab([],[],_,AccT,Vmax) -> {Vmax,lists:reverse(AccT)}.



get_starting_point(Tab,Vmax) -> get_starting_point(Tab,Vmax,[]).
get_starting_point([[{Vmax,D}|Col]|_],Vmax,Acc) -> [[{Vmax,D}|Col]|Acc];
get_starting_point([Col|Tab],Vmax,Acc) -> get_starting_point(Tab,Vmax,[Col|Acc]).

	
% d=deletion, i=insertion, m=match/mismatch
get_CIGAR(Tab,Vmax) -> 
	io:format("Max: ~p~n",[Vmax]),
	Tab1 = get_starting_point(Tab,Vmax),

	io:format("Tab: ~n~p~n",[Tab1]),
	[ [{_,Dir}|Column] | Tab2 ] = Tab1,
	case Dir of
		up -> get_CIGAR(Tab2,Column,1,Dir,1,""); % eat current column 
		_ -> get_CIGAR(Tab2,1,Dir,1,"")  % eat next column
	end.
	
get_CIGAR([Column|Tab],Skip,Dir,N,CIGAR) ->
	ColTail = lists:nthtail(Skip,Column),
	get_CIGAR(Tab,ColTail,Skip,Dir,N,CIGAR).


get_CIGAR(Tab,[{_,up}|Column],Skip,up,N,CIGAR) ->	
	get_CIGAR(Tab,Column,Skip+1,up,N+1,CIGAR);
get_CIGAR(Tab,[{_,up}|Column],Skip,Dir,N,CIGAR)	->
	get_CIGAR(Tab,Column,Skip,up,1,get_str(N,Dir)++CIGAR);
get_CIGAR(Tab,[{_,Dir}|_],Skip,Dir,N,CIGAR) ->
	case Dir of
		up_left -> get_CIGAR(Tab,Skip+1,Dir,N+1,CIGAR);
		left -> get_CIGAR(Tab,Skip,Dir,N+1,CIGAR)
	end;

get_CIGAR(_,[{_,undef}],_,Dir,N,CIGAR) -> get_str(N,Dir)++CIGAR;

get_CIGAR(Tab,[{_,Dir2}|_],Skip,Dir1,N,CIGAR) ->
	case Dir2 of
		up_left -> get_CIGAR(Tab,Skip+1,Dir2,1,get_str(N,Dir1)++CIGAR);
		left -> get_CIGAR(Tab,Skip,Dir2,1,get_str(N,Dir1)++CIGAR)
	end.



get_str(N,Dir) ->
	integer_to_list(N)++case Dir of
							up_left -> "M";
							left  -> "D";
							up  -> "I"
						end.
 


sigma(S,S) -> ?MATCH;
sigma(_,$N) -> ?MATCH;

sigma($A,$R) -> ?MATCH;
sigma($G,$R) -> ?MATCH;
sigma(_, $R) -> ?MISMATCH;

sigma($C,$Y) -> ?MATCH;
sigma($T,$Y) -> ?MATCH;
sigma(_, $Y) -> ?MISMATCH;

sigma($A,$B) -> ?MISMATCH;
sigma(_, $B) -> ?MATCH;

sigma($C,$D) -> ?MISMATCH;
sigma(_, $D) -> ?MATCH;

sigma($G,$K) -> ?MATCH;
sigma($T,$K) -> ?MATCH;
sigma(_, $K) -> ?MISMATCH;

sigma($A,$M) -> ?MATCH;
sigma($C,$M) -> ?MATCH;
sigma(_, $M) -> ?MISMATCH;

sigma($G,$S) -> ?MATCH;
sigma($C,$S) -> ?MATCH;
sigma(_, $S) -> ?MISMATCH;

sigma($A,$W) -> ?MATCH;
sigma($T,$W) -> ?MATCH;
sigma(_, $W) -> ?MISMATCH;

sigma($T,$V) -> ?MISMATCH;
sigma(_, $V) -> ?MATCH;

sigma(_,_) -> ?MISMATCH.

