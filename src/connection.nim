import overrides/[asyncnet]
import std/[tables,times,random,parseutils, asyncdispatch, strformat,strutils, net, random,bitops]
import globals,pipe


var lgid:uint32 = 1
proc new_uid:uint32 = 
    result =  lgid
    inc lgid


type
    TrustStatus*{.pure.} = enum 
        no,pending,yes

    Connection* = ref object
        recv_buffer*:string
        id*:uint32
        creation_time*:uint
        trusted*:TrustStatus
        address*:string        
        socket*:AsyncSocket
            
    Connections* = object
        connections*: Table[uint32, Connection]

# proc has(cons:Connections,con:Connection):bool =cons.connections.hasKey(con.id)

template send*(con:Connection,data:string):untyped  = con.socket.send(data)
template recv*(con:Connection,data:SomeInteger):untyped = con.socket.recv(data)


proc sendF*(con:Connection,data:string){.async.}=
    await send(con,data)
    # var dlen = data.len()
    # var index = 0
    # while dlen > 1024:
    #     let s = 1024
    #     dlen = dlen-1024
    #     index = index + 1024
    #     await con.socket.send(unsafeAddr data[index],1024)

    # if dlen > 0:
    #     await con.socket.send(unsafeAddr data[index],dlen)



proc isClosed*(con:Connection):bool = con.socket.isClosed()
template close*(con:Connection) = con.socket.close()

proc close*(cons:var Connections,con: Connection) =
    con.socket.close()
    if cons.connections.hasKey(con.id):
        cons.connections.del(con.id)

proc isTrusted*(con:Connection):bool= con.trusted == TrustStatus.yes

proc takeRandom*(cons:Connections):Connection = 
    var chosen = rand(cons.connections.len()-1)
    for k in cons.connections.keys:
        if chosen == 0:
            return cons.connections[k]
        dec chosen

    raise newException(ValueError, "could not take random conn")




proc newConnection*(socket : AsyncSocket = nil ,address:string, buffered:bool =  globals.socket_buffered):Connection=
    new(result)
    # result.recv_buffer =  newStringOfCap(globals.connection_buf_cap)
    # if id == 0 : result.id = new_uid()
    result.id = 0
    result.creation_time = epochTime().uint32
    result.trusted = TrustStatus.pending
    result.address = address

    if socket == nil: result.socket =  newAsyncSocket(buffered = buffered)
    else:result.socket = socket
    
    result.socket.setSockOpt(OptNoDelay, true)

proc register*(cons: var Connections, con: Connection)=
    if con.id == 0:
        con.id = new_uid()
    assert not cons.connections.hasKey con.id

    cons.connections[con.id] = con
