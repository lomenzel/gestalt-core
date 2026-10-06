# modules/view/subscriptions/veilid.nix
{ lib, config, ... }:
{
  config.Sub.Veilid = {
    # Live Network Statistics (bandwidth bpsDown/bpsUp, peer table, node IDs)
    # onNetwork receives: ({ started, bpsDown, bpsUp, peers, peersCount, nodeIds, primaryNodeId }, state): ...
    onNetwork =
      { onNetwork }:
      {
        kind = "Veilid.Network";
        key = "veilid:network";
        onNetwork = config.mkCallback onNetwork;
      };

    # Listen for fire-and-forget deltas arriving on any of our routes
    # onMessage receives: ({ message, routeId }, state): ...
    onAppMessage =
      { onMessage }:
      {
        kind = "Veilid.AppMessage";
        key = "veilid:app-messages";
        onMessage = config.mkCallback onMessage;
      };

    # Listen for incoming RPC calls from peers (must reply with appCallReply)
    # onCall receives: ({ callId, message, routeId }, state): ...
    onAppCall =
      { onCall }:
      {
        kind = "Veilid.AppCall";
        key = "veilid:app-calls";
        onCall = config.mkCallback onCall;
      };

    # Dynamically watch a DHT record for updates (e.g. peer route changes)
    # onUpdate receives: ({ key, subkey, data }, state): ...
    watchDht =
      {
        dhtKey,
        subkeys ? [ 0 ],
        onUpdate,
      }:
      {
        kind = "Veilid.WatchDht";
        key = "veilid:dht:${dhtKey}:${lib.concatMapStringsSep "-" toString subkeys}";
        params = {
          key = dhtKey;
          inherit subkeys;
        };
        onUpdate = config.mkCallback onUpdate;
      };

    # Track Veilid network connectivity (attached, detached, peering)
    # onChange receives: ({ state }, state): ...
    onAttachment =
      { onChange }:
      {
        kind = "Veilid.Attachment";
        key = "veilid:attachment";
        onChange = config.mkCallback onChange;
      };
   
    # Track route health (detect when a private route has collapsed)
    # onChange receives: ({ deadRoutes, deadRemoteRoutes }, state): ...
    onRouteChange =
      { onChange }:
      {
        kind = "Veilid.RouteChange";
        key = "veilid:route-change";
        onChange = config.mkCallback onChange;
      };
  };
}
