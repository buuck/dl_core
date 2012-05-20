%% dl_conf_mgr.erl
%% @doc The dripline configuration manager module.  Uses
%%      Mnesia as a backend for storing configuration data.
-module(dl_conf_mgr).
-behavior(gen_dl_agent).

-record(state,{id}).

-export([start_link/2,
	 init/1,
	 handle_sb_msg/2,
	 handle_info/2,
	 handle_cast/2,
	 handle_call/3,
	 code_change/3,
	 terminate/2]).

%%%%%%%%%%%%%%%%%%%%%%%%
%%% Includes for QLC %%%
%%%%%%%%%%%%%%%%%%%%%%%%
-include_lib("stdlib/include/qlc.hrl").

%%%%%%%%%%%%%%%%%%%%%
%%% API Functions %%%
%%%%%%%%%%%%%%%%%%%%%
-export([local_channels/0]).

%%%%%%%%%%%%%%%%%%%%%%%
%%% API Definitions %%%
%%%%%%%%%%%%%%%%%%%%%%%
local_channels() ->
    gen_dl_agent:call(?MODULE, local_ch).

start_link(?MODULE, _Args) ->
    gen_dl_agent:start_link(?MODULE, ?MODULE).

init([ID|_T]) ->
    ok = create_mnesia_tables(),
    {ok, #state{id=ID}}.

handle_sb_msg({_Ref, Id, _Msg}, #state{id=Id}=State) ->
    {noreply, State};
handle_sb_msg({_Ref, _OtherId, _Msg}, #state{}=State) ->
    {noreply, State}.

handle_info(_Info, StateData) ->
    {noreply, StateData}.

handle_call(local_ch, _From, StateData) ->
    {reply, get_local_chs(), StateData}.

handle_cast(_Cast, StateData) ->
    {noreply, StateData}.

code_change(_Version, StateData, _Extra) ->
    {ok, StateData}.

terminate(_Reason, _StateData) ->
    ok.

%%%%%%%%%%%%%%%%
%%% Internal %%%
%%%%%%%%%%%%%%%%
-spec create_mnesia_tables() -> ok | term().
create_mnesia_tables() ->
    ok = create_ch_data_table().

-spec create_ch_data_table() -> ok | term().
create_ch_data_table() ->
    case mnesia:create_table(dl_ch_data,
			     [
			      {ram_copies, [node()]},
			      {attributes, dl_ch_data:fields()}
			     ]) of
	{atomic, ok} ->
	    ok;
	{aborted,{already_exists,dl_ch_data}} ->
	    ok;
	AnyOther ->
	    AnyOther
    end.

-spec get_local_chs() -> [atom()].
get_local_chs() ->
    Qs = qlc:q([Ch || Ch <- mnesia:table(dl_ch_data),
		      dl_ch_data:get_node(Ch) == local
	       ]),
    {atomic, Ans} = mnesia:transaction(fun() ->
					       qlc:e(Qs)
				       end),
    Ans.