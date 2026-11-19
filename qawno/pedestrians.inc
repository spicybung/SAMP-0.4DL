#if defined _pedestrians_included
    #endinput
#endif
#define _pedestrians_included

#define PEDESTRIANS_VERSION_MAJOR (0)
#define PEDESTRIANS_VERSION_MINOR (2)
#define PEDESTRIANS_AMBIENT_CAP   (80)

// Opt-in marker. Ambient peds are generated/networked automatically; no ped list.
forward __PedestriansEnabled();
public __PedestriansEnabled() { return 1; }

native PedTraffic_GetCount();
native PedTraffic_GetAuthority();

native PedTraffic_GetVehicleCount();

native bool:DisableSourcePeds(bool:disable = true);
