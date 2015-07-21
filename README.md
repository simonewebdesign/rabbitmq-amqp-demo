# OrientDB/RabbitMQ Elixir

A RabbitMQ consumer application that stores messages in OrientDB.

## Getting started

- Clone this repo
- Install the dependencies: `mix deps.get`
- Initialize the Docker containers: `./bin/docker-run-orientdb.sh ; ./bin/docker-run-rabbitmq.sh`

## A Walkthrough

This Elixir app is a RabbitMQ *consumer* (i.e. client).

In order to send messages you need a RabbitMQ *producer* (i.e. server). You can use whatever you want. For the sake of simplicity I've added one under the bin folder. Run `./bin/rabbitmqadmin --help` to see what are the available options.

Basically what we want to do is:

1. Create a queue in RabbitMQ
2. Send a couple messages to that queue
3. Get the messages using the Elixir consumer
4. Store the messages in OrientDB

### 1. Create a queue in RabbitMQ

Run this command:

    ./bin/rabbitmqadmin declare queue name=myqueue --host=$DOCKER_IP -P 15672 -u guest -p guest

If everything went well, you should see *queue declared* in the console. You should also be able to access the RabbitMQ management web app on `http://YOUR_DOCKER_IP:15672/`. Username `guest` password `guest`. The queue `myqueue` should be listed there as well.

### 2. Send a couple messages to that queue

Run this command:

    ./bin/rabbitmqadmin publish routing_key=myqueue payload="Hello, World!" --host=$DOCKER_IP -P 15672 -u guest -p guest

Let's send another message:

    ./bin/rabbitmqadmin publish routing_key=myqueue payload="Elixir Rocks!" --host=$DOCKER_IP -P 15672 -u guest -p guest

If everything went well, your console should have said *Message published* twice.

You can send a third one using the Elixir client, [AMQP](https://github.com/pma/amqp):

``` elixir
iex -S mix
Erlang/OTP 17 [erts-6.4] [source] [64-bit] [smp:8:8] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

Compiled lib/consumer.ex
Generated consumer app
Interactive Elixir (1.0.5) - press Ctrl+C to exit (type h() ENTER for help
iex(1)> {:ok, conn} = AMQP.Connection.open host: "YOUR_DOCKER_IP"  # Tweak this
{:ok, %AMQP.Connection{pid: #PID<0.168.0>}}
iex(2)> {:ok, chan} = AMQP.Channel.open(conn)
{:ok,
 %AMQP.Channel{conn: %AMQP.Connection{pid: #PID<0.168.0>}, pid: #PID<0.178.0>}}
iex(3)> AMQP.Exchange.declare chan, "myqueue"  # redeclaring a queue is idempotent, so nothing happens
:ok
iex(4)> AMQP.Exchange.declare chan, "test_exchange"
:ok
iex(5)> AMQP.Queue.bind chan, "myqueue", "test_exchange"
:ok
iex(6)> AMQP.Basic.publish chan, "test_exchange", "", "Hi there!"
:ok
```

You can check that RabbitMQ is storing the messages from the management tool, or from the command line:

```
rabbitmqadmin list queues --host=$DOCKER_IP -P 15672 -u guest -p guest
+---------+----------+
|  name   | messages |
+---------+----------+
| myqueue | 3        |
+---------+----------+
```

### 3. Get the messages using the Elixir consumer

The messages are waiting on `myqueue` to be consumed. Let's get them.

```
iex -S mix
Erlang/OTP 17 [erts-6.4] [source] [64-bit] [smp:8:8] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

Interactive Elixir (1.0.5) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)> {:ok, conn} = AMQP.Connection.open host: "boot2dockerip"
{:ok, %AMQP.Connection{pid: #PID<0.142.0>}}
iex(2)> {:ok, chan} = AMQP.Channel.open(conn)
{:ok,
 %AMQP.Channel{conn: %AMQP.Connection{pid: #PID<0.142.0>}, pid: #PID<0.154.0>}}
iex(3)> {:ok, payload, meta} = AMQP.Basic.get chan, "myqueue"
{:ok, "Hello, World!",
 %{app_id: :undefined, cluster_id: :undefined, content_encoding: :undefined,
   content_type: :undefined, correlation_id: :undefined, delivery_tag: 1,
   exchange: "", expiration: :undefined, headers: :undefined, message_count: 2,
   message_id: :undefined, persistent: false, priority: :undefined,
   redelivered: false, reply_to: :undefined, routing_key: "myqueue",
   timestamp: :undefined, type: :undefined, user_id: :undefined}}
iex(4)> {:ok, payload, meta} = AMQP.Basic.get chan, "myqueue"
{:ok, "Elixir Rocks!",
 %{app_id: :undefined, cluster_id: :undefined, content_encoding: :undefined,
   content_type: :undefined, correlation_id: :undefined, delivery_tag: 2,
   exchange: "", expiration: :undefined, headers: :undefined, message_count: 1,
   message_id: :undefined, persistent: false, priority: :undefined,
   redelivered: false, reply_to: :undefined, routing_key: "myqueue",
   timestamp: :undefined, type: :undefined, user_id: :undefined}}
iex(5)> {:ok, payload, meta} = AMQP.Basic.get chan, "myqueue"
{:ok, "Hi there!",
 %{app_id: :undefined, cluster_id: :undefined, content_encoding: :undefined,
   content_type: :undefined, correlation_id: :undefined, delivery_tag: 3,
   exchange: "test_exchange", expiration: :undefined, headers: :undefined,
   message_count: 0, message_id: :undefined, persistent: false,
   priority: :undefined, redelivered: false, reply_to: :undefined,
   routing_key: "", timestamp: :undefined, type: :undefined,
   user_id: :undefined}}
iex(6)> {:ok, payload, meta} = AMQP.Basic.get chan, "myqueue"
** (MatchError) no match of right hand side value: {:empty, %{cluster_id: ""}}

iex(6)> payload
"Hi there!"
```

You can see from above that I called the same command 4 times. You can get the messages this way, however you'll get a `MatchError` in case you try to get a message from an empty queue.

### 4. Store the messages in OrientDB

First, let's create a database.

``` bash
docker exec -it orient bash

root@1d5a5c35c4ef:/# ./usr/local/src/orientdb/bin/console.sh

OrientDB console v.2.0.12 (build UNKNOWN@r; 2015-07-01 11:28:05+0000) www.orientechnologies.com
Type 'help' to display all the supported commands.

orientdb> create database remote:localhost/mydatabase root 0r13ntDB plocal

Creating database [remote:localhost/mydatabase] using the storage type [plocal]...
Connecting to database [remote:localhost/mydatabase] with user 'admin'...OK
Database created successfully.

orientdb {db=mydatabase}> create class Report

Class created successfully. Total classes in database now: 11

orientdb {db=mydatabase}> create property Report.origin_id integer

Property created successfully with id=1

orientdb {db=mydatabase}> create property Report.reference string

Property created successfully with id=2

orientdb {db=mydatabase}> create property Report.version integer

Property created successfully with id=3

orientdb {db=mydatabase}> info class Report

Class................: Report
Default cluster......: report (id=11)
Supported cluster ids: [11]
Cluster selection....: round-robin
PROPERTIES
-------------------------------+-------------+-------------------------------+-----------+----------+----------+-----------+-----------+----------+
 NAME                          | TYPE        | LINKED TYPE/CLASS             | MANDATORY | READONLY | NOT NULL |    MIN    |    MAX    | COLLATE  |
-------------------------------+-------------+-------------------------------+-----------+----------+----------+-----------+-----------+----------+
 origin_id                     | INTEGER     | null                          | false     | false    | false    |           |           | default  |
 reference                     | STRING      | null                          | false     | false    | false    |           |           | default  |
 version                       | INTEGER     | null                          | false     | false    | false    |           |           | default  |
-------------------------------+-------------+-------------------------------+-----------+----------+----------+-----------+-----------+----------+
```

Now that we have a database and a class with its cluster in OrientDB, we can start storing reports in it.

