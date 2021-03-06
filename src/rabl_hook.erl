%%% @author Russell Brown <russell@wombat.me>
%%% @copyright (C) 2017, Russell Brown
%%% @doc
%%
%%% riak post commit hook that sends an object to the configured
%%% rabbitmq queue. NOTE: Expects an exchange and routing key named
%%% for the cluster to be configured. The application environment
%%% setting {rabl, cluster_name} should be the name of a queue and
%%% exchange that are set up on rabbitmq for this hook to publish to
%%% as the source of changes to replicate.
%%
%%% @end
%%
%%% @see rabl_util for helper functions to set up queue etc. There
%%% should be operator commands in rabl_escript
%%
%%% Created : 20 Apr 2017 by Russell Brown
%%% <russell@wombat.me>

-module(rabl_hook).

-compile(export_all).

%% Simpliest thing that could work.
-spec rablicate(rabl_riak:riak_object()) -> ok |
                                              {fail, Reason::term()}.
rablicate(Object) ->
    lager:debug("rabl hook called~n"),
    BK = rabl_riak:object_bk(Object),
    BinObj = rabl_riak:object_to_binary(Object),
    Time = os:timestamp(),
    {ok, Msg} = rabl_codec:encode(Time, BK, BinObj),
    lager:debug("rablicating ~p~n", [BK]),
    Res = case rabl_producer_fsm:publish(Msg) of
              ok ->
                  rabl_stat:publish(),
                  ok;
              {error, blocked} ->
                  rabl_stat:publish_blocked();
              Error ->
                  rabl_stat:publish_fail(),
                  lager:error("Rablication error ~p", [Error]),
                  {fail, Error}
          end,
    Res.
