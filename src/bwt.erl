% A simple implementation of BWT
% 
% Cloudozer(c), 2014
%

-module(bwt).
-export([bwt/1,
		get_suffs/1,
		fm/1,
		sa/1,
		make_index/1,
		get_ref/3,
		get_index/1,
		test/0
		]).

-include("bwt.hrl").

%-define(TRSH,0.8).


%-record(fm,{f,l,d,a,c,g,t,sa}).

test() ->
  %{Meta,FM} = get_index("GL000192.1"),
  {Meta,FM} = get_index("GL000207.1"),
  {Pc,Pg,Pt} = proplists:get_value(pointers, Meta),
  Qs = [
  	"ACCCCACGTTTTTGGAGTTATATGTTGGCACTGATACTGGCCATAGAATTCCCTATGGTA",
    "ACCNNNNCCACGTTTTTGGAGTTATATGTTGATACTGGCCATAGAATTCCCTATNGGTA",
    "ACCCCACGTTTTTGGAGTTATATGTTGTTCTTGCACTGATACTGGCCATAGAATTCCCTATGGTA",
    
    "CTCAGCCTCCATAATTATGTGAACCAGTTCCCCTAATGAATCTTCTCTCATCTGTCTACA",
    "TATATCCTATTGATTCTGCCTTTCTGGAGACCCCTGACTAATGTGATTACAATAACTACA",
    "CAATTCACTAGTTTATATAGAAGACTTGGTTTTTGTCTTTGCCCCATTTTATATTTGTAT",
    "TATAACTATGTATCTGGAAAATGGAACAAGTTTTTTCTTCTTCATATGAGGGCTAAGGCT",
    "TTTTTCTCACCAATATTTTTGGAGATTTTAAAGATTTTCTTTTTTTTTGACATAGAATCT",
    "TATGGAGGCTGAGAAATAATTTTTTTTCTATTTTATTCTTCAGCCCCAGGTGTTTGCTTT",
    "TGCAGATTCTTGAGCACACTGAGAGCCTCCAAGGCATGGAGTGGGGTGCCTGAAGTTTCA",
    "CAATATCATCAGAAGCCTATAACCAGAGTACCTGTCATAGTCTTTTCTGTGAGTCTCAGA",
    "GGGAGTCCTGTCTTGGAGACGAACATTCTGACCTGTAGTTGATTGCAGGAGCTTTCAGGA",
    "AAGCATCAGGGGGAAATAATATCTAAATGACGAAAAGTATGAAATGGCTGTGATGAAAGA",
    "TCTGATGAGAGTTCATTATACCACAACTGACAAGGATATTCGATTTTTTCTGTGGCAGAC",
    "AACATTTATTTATTTCTTTATTTAGAGACAGAGTCTTGCTCTGTCGCCCAGGCTGGAGTG",
    "CAGCGGTGCGATCTCGGCTCACTGCAAGCTCTGTCTCCTGGGTTCACGCCATTCTCCTGC",
    "CTCAGCCTCCCGAGTAGCTGGGACTACAGGTGCCTGCCATCACGCCCGGCTAATTTTTTA",
    "TATTTTTAATAGAGATGGAGATTCACCGGGTTAGCCAGGATGGTCTGGATCTCCTGACCT",
    "TGTGATCCACCCGCCTCAGCCTCCTAAAGTGCTGGGATTATAGGCATGAGCCACTGTGCC",
    "TGGCACAACATTTAAAGTAATAATTGGAATTATGACTCATTACTCTATAGTGGCACATAG",
    "CATGGATAAGGAGGACATTGACAAACTTCCAGGAATTTTATATAATTTCTGAAAACATAA",
    "CATTTTACCCATACAAATATAACACAGGGAAGGTTAGGTATCTCTTTTTATTTGTATCTT",
    "CTGTATGGTTTTCCTTATAAAAAATGCAACCTACTTTACTTGCGAAACATGCCCTACTTT",
    "TCTTGCATGCTTTGCATAGAGTTGTTTCTAGTTATTCTATTATTTCTAGTAGTTTTATTT",
    "ACATATATTGATTATAATTTTAATACTTAGTAATCTTTTATTTTCCAGAGAAAACTAGGA",
    "AGTAGACAGTTATAAACTGTCATATATTAGCATTCTATAGTAGGTTAGAAAATGTATGAA",
    "TATACCATCTCCCAACATCTAGAGGGATGTGTTTTCTCATAATACAATTCCTCAGTGTGG",
    "CAGAAAAAAACATGTTTATTAACGGGCCAAAATATCTTTAGTCTCTCTGTAAAAACAGGA",
    "AGCCAAAAGTATATAAACTTGAATTATTTATGTTCAGTAATTAATGTTTTAGTATTGTAT",
    "CTTATTTATAAATGGTCTAGATATTTAATGCAAATCTTTTACTTAGCTTAACTTTAAGGT",
    "TAAAAATTACCAAAAGTACTTTGGAAACTATTCTTAGGCAGATTTACTGTAAACAAATTA"
  ],

  lists:foreach(fun(Qseq) -> {T,_}=timer:tc(sga,sga,[FM,Pc,Pg,Pt,Qseq]), io:format("~p <--> ~b~n", [Qseq,T]) end, Qs).



make_index(Chrom) ->
	ok = application:start(bwt),
	{ok, BwtFiles} = application:get_env(bwt,bwt_files),
	File = filename:join(BwtFiles, "human_g1k_v37_decoy.fasta"),
	{Pos,Len} = msw:get_reference_position(Chrom,File),
	{Shift,Ref_seq} = msw:get_ref_seq(File,Pos,Len),
	io:format("Removed ~p 'NNN' in the beginning~n",[Shift]),
	io:format("Length of the ref genome: ~p~n",[length(Ref_seq)]),
	statistics(runtime),
	Ref_seq1 = lists:map(fun($N)->$A;
							($B)->$C;
							($D)->$G;
							($R)->$A;
							($Y)->$C;
							($K)->$T;
							($M)->$A;
							($S)->$C;
							($W)->$A;
							($V)->$A;
							($A)->$A;
							($C)->$C;
							($G)->$G;
							($T)->$T
						end, Ref_seq),
	{_,T1} = statistics(runtime),
	io:format("Maping takes: ~pms~n",[T1]),
	file:write_file(filename:join(BwtFiles,Chrom++".ref"),list_to_binary(Ref_seq1)),

	FM = fm(st:append($$,Ref_seq1)),
	Meta = [{pointers, fmi:get_3_pointers(FM)},{shift, Shift}],
	Bin = term_to_binary({Meta,FM}),
	file:write_file(filename:join(BwtFiles,Chrom++".fm"),Bin).



get_index(Chrom) ->
	{ok, BwtFiles} = application:get_env(bwt,bwt_files),
	{ok,Bin} = file:read_file(filename:join(BwtFiles, Chrom++".fm")),
	%{ok,Bin} = file:read_file(filename:join("bwt_files/", Chrom++".fm")),
	binary_to_term(Bin).



get_ref(Chrom,Pos,Len) ->
	{ok, BwtFiles} = application:get_env(bwt,bwt_files),
	File = filename:join(BwtFiles, Chrom++".ref"),
	{ok,Dev} = file:open(File,read),
	{ok,Ref} = file:pread(Dev, Pos, Len),
	ok = file:close(Dev),
	binary_to_term(Ref).




bwt(X) ->
	T = lists:reverse([$$|lists:reverse(X)]),

	N = length(T),

	Permutations = get_all_permutations([],T,N,N),
	%lists:foreach(fun(S)-> io:format("~p~n",[S]) end, Permutations),
	%io:format("~n"),
	[ lists:nth(N,Seq) || Seq <- Permutations].
	

get_all_permutations(Acc,_,0,_) -> lists:sort(Acc);
get_all_permutations(Acc,T,K,N) -> 
	{T1,Last} = lists:split(N-1,T),
	NewT = Last++T1,
	%io:format("NewT:~s~n",[NewT]),
	get_all_permutations([NewT|Acc],NewT,K-1,N).


%% returns an FM index for a given reference sequence
fm(X) ->
	_ = statistics(runtime),
	SA = st:sa_seq(X),
	{_,T2} = statistics(runtime),
	io:format("Suffix array generation took: ~psec~n",[T2/1000]),
	%io:format("Sufs:~p~n",[Ls]),
	{FM,Dq,Aq,Cq,Gq,Tq} = fm(X,SA,$$,[],1,[],[],[],[],[]),
	{_,T3} = statistics(runtime),
	io:format("Building the queues took ~p sec~n",[T3/1000]),

	%list_to_tuple(add_indices(FM,[],Dq,Aq,Cq,Gq,Tq)).
	list_to_tuple(fmi:assemble_index(FM,[],0,[],Dq,Aq,Cq,Gq,Tq)).
	
	%{_,T4} = statistics(runtime),
	%io:format("Building the index took ~p sec~n",[T4/1000]).



fm([S|X],[N|SA],P,Acc, K, Dq,Aq,Cq,Gq,Tq) ->
	case S of
		$A -> fm(X,SA,$A,[{S,P,N}|Acc],K+1,Dq,[K|Aq],Cq,Gq,Tq);
		$C -> fm(X,SA,$C,[{S,P,N}|Acc],K+1,Dq,Aq,[K|Cq],Gq,Tq);
		$G -> fm(X,SA,$G,[{S,P,N}|Acc],K+1,Dq,Aq,Cq,[K|Gq],Tq);
		$T -> fm(X,SA,$T,[{S,P,N}|Acc],K+1,Dq,Aq,Cq,Gq,[K|Tq]);
		$$ -> fm(X,SA,$$,[{S,P,N}|Acc],K+1,[K|Dq],Aq,Cq,Gq,Tq)
	end;
fm([],[],$$,Acc,_, Dq,Aq,Cq,Gq,Tq) -> 
	{lists:reverse(Acc),
	lists:reverse(Dq),
	lists:reverse(Aq),
	lists:reverse(Cq),
	lists:reverse(Gq),
	lists:reverse(Tq)
	}.
				



sa(X) ->
	Ls = lists:sort(get_suffs(X)),
	[ N || {_,N,_} <- Ls].



get_suffs(X) ->
	X1 = lists:reverse([$$|lists:reverse(X)]),
	get_suffs([],0,X1,$$).

get_suffs(Acc, N, [H|X],P) ->
	get_suffs([{[H|X],N,P}|Acc], N+1, X, H);
get_suffs(Acc,_,[],_) -> 
	%io:format("Suffices:~n~p~n",[Acc]),
	Acc.


