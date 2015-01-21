-module(worker_bwt).
-behaviour(gen_fsm).
%% API
-export([start_link/0, run/2,
seq_file_reader/1, seq_file_reader_loop/1, worker_loop/6]).
%% Callbacks
-export([init/1, idle/3, busy/2]).

-record(state, {workload, current_workload = [], current_worker, master_pid, seq, ref_file_abs, seq_reader}).

start_link() ->
  gen_fsm:start_link({local, ?MODULE}, ?MODULE, {}, []).

run(Pid, Args) ->
  {ok, WorkerPid} = gen_fsm:sync_send_event(Pid, {run, Args}),
  true = link(WorkerPid),
  ok.


init(_Args) ->
  {ok, idle, #state{}}. 

%handle_info({'DOWN', Ref, process, Pid, normal}, busy, S=#state{current_worker={Pid,Ref}}) ->
%lager:info("exi"),
%  {next_state, idle, S#state{current_worker = undefined}}.


idle({run, Args}, _From, State = #state{}) ->
  {
    RefFile,IndexFile,SeqFile,WorkerPath,
    Workload,
    MasterPid
  } = Args,
  SeqsReaderPid = seq_file_reader(filename:absname_join(WorkerPath, SeqFile)),
  {ok, Seq} = get_next_seq(SeqsReaderPid),
  {SeqName, SeqData} = Seq,

  [{Pos,ChunkSize}|WorkloadRest] = Workload,

  RefFileAbs = filename:absname_join(WorkerPath, RefFile),
  Pid = spawn_link(?MODULE, worker_loop, [self(), MasterPid, SeqData, RefFileAbs, Pos, ChunkSize]),
  {reply, ok, busy, State#state{
    workload = Workload,
    current_workload = WorkloadRest,
    current_worker = Pid, 
    master_pid = MasterPid,
    seq = Seq,
    ref_file_abs = RefFileAbs,
    seq_reader = SeqsReaderPid
  }}.

busy({done, WorkPiece}, S=#state{
    current_workload = [],
    workload = [{Pos,ChunkSize}|WorkloadRest],
    master_pid = MasterPid,
    ref_file_abs = RefFileAbs,
    seq_reader = SeqsReaderPid
  }) ->

  {ok, Seq} = get_next_seq(SeqsReaderPid),
  {SeqName, SeqData} = Seq,

  Pid = spawn_link(?MODULE, worker_loop, [self(), MasterPid, SeqData, RefFileAbs, Pos, ChunkSize]),
  {next_state, busy, S#state{current_worker = Pid, current_workload = WorkloadRest}};
busy({done, WorkPiece}, S) ->
  #state{
    current_workload = [{Pos,ChunkSize}|WorkloadRest],
    current_worker = CurrentPid, 
    master_pid = MasterPid,
    seq = {_,SeqData},
    ref_file_abs = RefFileAbs
  } = S,

  Pid = spawn_link(?MODULE, worker_loop, [self(), MasterPid, SeqData, RefFileAbs, Pos, ChunkSize]),
  {next_state, busy, S#state{current_worker = Pid, current_workload = WorkloadRest}}.

%% Private

seq_file_reader(SeqFile) ->
  {ok, Dev} = file:open(SeqFile, [read]),
  spawn_link(?MODULE, seq_file_reader_loop, [Dev]).

seq_file_reader_loop(Dev) ->
  receive
    {get_seq, Ref, Pid} ->
      case seq_file_reader_loop_loop(Dev) of
        {ok, Seq} ->
          Pid ! {ok, Ref, Seq},
          seq_file_reader_loop(Dev);
        eof ->
          Pid ! eof
      end;
    _ ->
      exit(kill)
  end.

seq_file_reader_loop_loop(Dev) ->
  [Dot] = "@",
  case file:read_line(Dev) of
    {ok, [Dot | SeqName]} ->
      {ok, SeqData} = file:read_line(Dev),
      Seq = {lists:droplast(SeqName),
             lists:droplast(SeqData)},
      {ok, Seq};
    {ok, E} ->
      seq_file_reader_loop_loop(Dev);
    eof ->
      eof
  end.

get_next_seq(Pid) ->
  Ref = monitor(process, Pid),
  Pid ! {get_seq, Ref, self()},
  receive
    {ok, Ref, Seq = {_,SeqData}} ->
      true = demonitor(Ref),
      seeds:generate_fs(SeqData,15,2),
      compile:file("fs.erl",[report_errors]),
      code:add_path("."),
      case code:is_loaded(fs) of
        {file, _} -> true = purge(fs);
        false -> ok
      end,
      {module, fs} = code:load_file(fs),
lager:info("Next Seq = ~p", [Seq]),
      {ok, Seq};
    _ ->
      exit(kill)
  end.

worker_loop(WorkerMngrPid, MasterPid, Seq, RefFile, Pos, ChunkSize) -> 
  msw:worker(self(), Seq, RefFile, Pos, ChunkSize),
  Results = receive R -> R end,
  if (Results =/= []) -> 
    master:send_result(MasterPid, Results);
  true -> ok end,
  ok = gen_fsm:send_event(WorkerMngrPid, {done, {Pos, ChunkSize}}).
