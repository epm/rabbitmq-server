%%   The contents of this file are subject to the Mozilla Public License
%%   Version 1.1 (the "License"); you may not use this file except in
%%   compliance with the License. You may obtain a copy of the License at
%%   http://www.mozilla.org/MPL/
%%
%%   Software distributed under the License is distributed on an "AS IS"
%%   basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
%%   License for the specific language governing rights and limitations
%%   under the License.
%%
%%   The Original Code is RabbitMQ.
%%
%%   The Initial Developers of the Original Code are LShift Ltd,
%%   Cohesive Financial Technologies LLC, and Rabbit Technologies Ltd.
%%
%%   Portions created before 22-Nov-2008 00:00:00 GMT by LShift Ltd,
%%   Cohesive Financial Technologies LLC, or Rabbit Technologies Ltd
%%   are Copyright (C) 2007-2008 LShift Ltd, Cohesive Financial
%%   Technologies LLC, and Rabbit Technologies Ltd.
%%
%%   Portions created by LShift Ltd are Copyright (C) 2007-2009 LShift
%%   Ltd. Portions created by Cohesive Financial Technologies LLC are
%%   Copyright (C) 2007-2009 Cohesive Financial Technologies
%%   LLC. Portions created by Rabbit Technologies Ltd are Copyright
%%   (C) 2007-2009 Rabbit Technologies Ltd.
%%
%%   All Rights Reserved.
%%
%%   Contributor(s): ______________________________________.
%%

-module(rabbit_basic).
-include("rabbit.hrl").
-include("rabbit_framing.hrl").

-export([publish/1, message/4, properties/1, delivery/4]).
-export([publish/4, publish/7]).

%%----------------------------------------------------------------------------

-ifdef(use_specs).

-type(properties_input() :: (amqp_properties() | [{atom(), any()}])).
-type(publish_result() :: ({ok, routing_result(), [pid()]} | not_found())).

-spec(publish/1 :: (delivery()) -> publish_result()).
-spec(delivery/4 :: (bool(), bool(), maybe(txn()), message()) -> delivery()). 
-spec(message/4 :: (exchange_name(), routing_key(), properties_input(),
                    binary()) -> message()).
-spec(properties/1 :: (properties_input()) -> amqp_properties()).
-spec(publish/4 :: (exchange_name(), routing_key(), properties_input(),
                    binary()) -> publish_result()).
-spec(publish/7 :: (exchange_name(), routing_key(), bool(), bool(),
                    maybe(txn()), properties_input(), binary()) ->
             publish_result()).

-endif.

%%----------------------------------------------------------------------------

publish(Delivery = #delivery{
          message = #basic_message{exchange_name = ExchangeName}}) ->
    case rabbit_exchange:lookup(ExchangeName) of
        {ok, X} ->
            {RoutingRes, DeliveredQPids} = rabbit_exchange:publish(X, Delivery),
            {ok, RoutingRes, DeliveredQPids};
        Other ->
            Other
    end.

delivery(Mandatory, Immediate, Txn, Message) ->
    #delivery{mandatory = Mandatory, immediate = Immediate, txn = Txn,
              sender = self(), message = Message}.

message(ExchangeName, RoutingKeyBin, RawProperties, BodyBin) ->
    Properties = properties(RawProperties),
    {ClassId, _MethodId} = rabbit_framing:method_id('basic.publish'),
    Content = #content{class_id = ClassId,
                       properties = Properties,
                       properties_bin = none,
                       payload_fragments_rev = [BodyBin]},
    #basic_message{exchange_name  = ExchangeName,
                   routing_key    = RoutingKeyBin,
                   content        = Content,
                   persistent_key = none}.

properties(P = #'P_basic'{}) ->
    P;
properties(P) when is_list(P) ->
    %% Yes, this is O(length(P) * record_info(size, 'P_basic') / 2),
    %% i.e. slow. Use the definition of 'P_basic' directly if
    %% possible!
    alist_to_properties(P).

alist_to_properties([]) ->
    #'P_basic'{};
alist_to_properties([{Key, Value} | Rest]) ->
    case indexof(record_info(fields, 'P_basic'), Key) of
        0 -> throw({unknown_P_basic_property_name, Key});
        N -> setelement(N, alist_to_properties(Rest), Value)
    end.

indexof(L, Element) -> indexof(L, Element, 0).

indexof([], _Element, _N)              -> 0;
indexof([Element | _Rest], Element, N) -> N;
indexof([_ | Rest], Element, N)        -> indexof(Rest, Element, N + 1).

%% Convenience function, for avoiding round-trips in calls across the
%% erlang distributed network.
publish(ExchangeName, RoutingKeyBin, Properties, BodyBin) ->
    publish(ExchangeName, RoutingKeyBin, false, false, none, Properties,
            BodyBin).

%% Convenience function, for avoiding round-trips in calls across the
%% erlang distributed network.
publish(ExchangeName, RoutingKeyBin, Mandatory, Immediate, Txn, Properties,
        BodyBin) ->
    publish(delivery(Mandatory, Immediate, Txn,
                     message(ExchangeName, RoutingKeyBin,
                             properties(Properties), BodyBin))).
