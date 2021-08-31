-module(person).
-behaviour(gen_server).
-export([start_link/1]). % convenience call for startup
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]). % gen_server callbacks

-record(state, {chat_node, profile}).

% internal functions
-export([login/1, logout/0, say/1, users/0, who/2, set_profile/2]). 

-define(CLIENT, ?MODULE). % macro that defines this module as the client

%%% convenience method for startup
start_link(ChatNode) ->
  gen_server:start_link({local, ?CLIENT}, ?MODULE, ChatNode, []).

init(ChatNode)->
  io:format("Chat node is: ~p~n", [ChatNode]),
  {ok, #state{chat_node=ChatNode, profile=[]}}.

%% The server is asked to either:
%% a) return the chat host name from the state,
%% b) return the user profile
%% c) update the user profile
%% d) log a user in
%% e) send a message to all people in chat room
%% f) log a user out

handle_call(get_chat_node, _From, State) ->
  {reply, State#state.chat_node, State};

handle_call(get_profile, _From, State) ->
  {reply, State#state.profile, State};

handle_call({set_profile, Key, Value}, _From, State) ->
  case lists:keymember(Key, 1, State#state.profile) of
    true -> NewProfile = lists:keyreplace(Key, 1, State#state.profile,
      {Key, Value});
    false -> NewProfile = [{Key, Value} | State#state.profile]
  end,
  {reply, NewProfile,
    #state{chat_node = State#state.chat_node, profile=NewProfile}};

handle_call({login, UserName}, _From, State) ->
  Reply = gen_server:call({chatroom, State#state.chat_node}, {login, UserName, node()}),
  {reply, Reply, State};

handle_call({say, Text}, _From, State) ->
  Reply = gen_server:call({chatroom, State#state.chat_node}, {say, Text}),
  {reply, Reply, State};

handle_call(logout, _From, State) ->
  Reply = gen_server:call({chatroom, State#state.chat_node}, logout),
  {reply, Reply, State};

handle_call(_, _From, State) -> {ok, [], State}.

handle_cast({message, {FromUser, FromServer}, Text}, State) ->
  io:format("~s (~p) says: ~p~n", [FromUser, FromServer, Text]),
  {noreply, State};

handle_cast(_Request, State) ->
  io:format("Unknown request ~p~n", _Request),
  {noReply, State}.

handle_info(Info, State) ->
  io:format("Received unexpected message: ~p~n", [Info]),
  {noreply, State}.


terminate(_Reason, _State) ->
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

% internal functions

%% @doc Gets the name of the chat host. This is a really
%% ugly hack; it works by sending itself a call to retrieve
%% the chat node name from the server state.

get_chat_node() ->
  gen_server:call(person, get_chat_node). %change person to MODULE for interesting


%% @doc Login to a server using a name
%% If you connect, tell the server your user name and node.
%% You don't need a reply from the server for this.
-spec(login(string()) -> term()).
login(UserName) ->
  if %re-write this
    is_atom(UserName) ->
      gen_server:call(?CLIENT,
        {login, atom_to_list(UserName)});
    is_list(UserName) ->
      gen_server:call(?CLIENT,
        {login, UserName});
    true ->
      {error, "User name must be an atom or a list"}
  end.


%% @doc Log out of the system. The person server will send a From that tells
%% who is logging out; the chatroom server doesn't need to reply.
-spec(logout() -> atom()).
logout() ->
  gen_server:call(?CLIENT, logout),
  ok.


%% @doc Send the given Text to the chat room server. No reply needed.
-spec(say(string()) -> atom()).
say(Text) ->
  gen_server:call(?CLIENT, {say, Text}),
  ok.

%% @doc Ask chat room server for a list of users.
-spec(users() -> [string()]).
users() ->
  gen_server:call({chatroom, get_chat_node()}, users).

%% @doc Ask chat room server for a profile of a given person.
-spec(who(string(), atom()) -> [tuple()]).
who(Person, ServerRef) ->
  gen_server:call({chatroom, get_chat_node()},
    {who, Person, ServerRef}).


%% @doc Update profile with a key/value pair.
-spec(set_profile(atom(), term()) -> term()).
set_profile(Key, Value) ->
  % ask *this* server for the current state
  NewProfile = gen_server:call(?CLIENT, {set_profile, Key, Value}),
  {ok, NewProfile}.






