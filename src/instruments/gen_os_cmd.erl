% gen_os_cmd.erl
% Behavior for "instruments" which are really operating system
% commands.  The behavior module wraps a gen_server, and the
% callback module defines its 'base' command, and a list of
% valid options.  When the execute command is sent in, the base
% command along with the options that are passed in is executed
% via os:cmd.
-module(gen_os_cmd).
-behaviour(gen_server).

-export([behaviour_info/1]).

%%%%%%%%%%%
%%% API %%%
%%%%%%%%%%%
-export([execute/2]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% gen_server api and callbacks %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-export([start_link/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%%%%%%%%%%%%%%%%%%%%%%%%
%%% Internal records %%%
%%%%%%%%%%%%%%%%%%%%%%%%
-record(state,{mod, mod_sd, cmd_port, sndr, data}).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Behavior callback requirements %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
behaviour_info(callbacks) ->
    [
     {init,1},
     {start_link,1},
     {process_args, 2},
     {base_cmd, 0}
    ];
behaviour_info(_) ->
    undefined.

%%%%%%%%%%%%%%%%%%%%%%%
%%% API Definitions %%%
%%%%%%%%%%%%%%%%%%%%%%%
execute(ID,Arglist) when is_list(Arglist) ->
    gen_server:call(ID, {ex, Arglist}, infinity);
execute(ID,Arglist) ->
    execute(ID, [Arglist]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% gen_server API and callback definitions %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
start_link(CallbackMod,ID) ->
  gen_server:start_link({local, ID}, ?MODULE, [CallbackMod], []).

init([CallbackMod]=Args) ->
    case CallbackMod:init(Args) of
	{ok, ModStateData} = _StartOK ->
	    StateData = #state{
	      cmd_port = none,
	      mod = CallbackMod,
	      mod_sd = ModStateData,
	      sndr = none,
	      data = []
	     },
	    {ok, StateData};
	Failure ->
	    Failure
    end.

handle_call({ex, Args}, F, #state{mod=M,mod_sd=MSD,cmd_port=none}=SD) ->
    BaseCmd = M:base_cmd(),
    ArgList = M:process_args(Args,MSD),
    OSOpts = [exit_status, {args, ArgList}],
    {Reply, Port} = try
			P = erlang:open_port({spawn_executable, BaseCmd},
					     OSOpts),
			{ok, P}
		    catch
			C:E ->
			    {{error, {C,E}}, none}
		    end,
    case Port of
	none ->
	    {reply, Reply, SD#state{cmd_port=Port}};
	Port ->
	    {noreply, SD#state{cmd_port=Port, sndr=F}}
    end;
handle_call({ex, _Args}, _F, #state{cmd_port=_P}=SD) ->
    {reply, busy, SD}.

handle_cast(_Msg, State) ->
  {noreply, State}.

handle_info({P, {exit_status, _St}}, #state{cmd_port=P, sndr=F, data=D}=SD) ->
    FlatList = lists:flatten(lists:reverse(D)),
    gen_server:reply(F, erlang:list_to_binary(FlatList)),
    {noreply, SD#state{cmd_port=none, sndr=none, data=[]}};
handle_info({P, {data, Dt}}, #state{cmd_port=P,data=D}=SD) ->
    {noreply, SD#state{data=[Dt|D]}}.

terminate(_Reason, _State) ->
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.