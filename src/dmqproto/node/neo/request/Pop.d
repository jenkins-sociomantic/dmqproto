/*******************************************************************************

    Pop request protocol.

    Copyright:
        Copyright (c) 2016-2017 sociomantic labs GmbH. All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE.txt for details.

*******************************************************************************/

module dmqproto.node.neo.request.Pop;

/*******************************************************************************

    v0 Pop request protocol.

*******************************************************************************/

public abstract scope class PopProtocol_v0
{
    import dmqproto.node.neo.request.core.Mixins;

    import swarm.neo.node.RequestOnConn;
    import dmqproto.common.Pop;

    import ocean.transition;

    /***************************************************************************

        Mixin the constructor and resources member.

    ***************************************************************************/

    mixin RequestCore!();

    /***************************************************************************

        Request handler.

        Params:
            connection = connection to client
            msg_payload = initial message read from client to begin the request
                (the request code and version are assumed to be extracted)

    ***************************************************************************/

    final public void handle ( RequestOnConn connection,
        Const!(void)[] msg_payload )
    {
        auto ed = connection.event_dispatcher;
        auto parser = ed.message_parser;

        cstring channel_name;

        parser.parseBody(msg_payload, channel_name);

        bool subscribed;

        if (this.prepareChannel(channel_name, subscribed))
        {
            auto value = this.resources.getVoidBuffer();
            if ( this.getNextValue(*value) )
            {
                ed.send(
                    ( ed.Payload payload )
                    {
                        payload.addConstant(RequestStatusCode.Popped);
                        payload.addArray(*value);
                    }
                );
            }
            else
            {
                ed.send(
                    ( ed.Payload payload )
                    {
                        payload.addConstant(RequestStatusCode.Empty);
                    }
                );
            }
        }
        else
        {
            ed.send(
                ( ed.Payload payload )
                {
                    payload.addConstant(
                        subscribed
                        ? RequestStatusCode.Subscribed
                        :RequestStatusCode.Error
                    );
                }
            );
        }

        ed.flush();
    }

    /***************************************************************************

        Performs any logic needed to pop from the channel of the given name.

        Params:
            channel_name = channel to pop from
            subscribed = `true` if the return value is `false` because the
                channel has subscribers so it is not possible to pop from it

        Returns:
            `true` if the channel may be used

    ***************************************************************************/

    abstract protected bool prepareChannel ( cstring channel_name,
        out bool subscribed );

    /***************************************************************************

        Pop the next value from the channel, if available.

        Params:
            value = buffer to write the value into

        Returns:
            `true` if there was a value in the channel, false if the channel is
            empty

    ***************************************************************************/

    abstract protected bool getNextValue ( ref void[] value );
}
