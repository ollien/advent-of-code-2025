-module(day9_ffi).
-export([num_schedulers/0]).

num_schedulers() ->
  erlang:system_info(schedulers).
