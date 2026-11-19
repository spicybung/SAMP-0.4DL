#define FILTERSCRIPT
#include <open.mp>
#include <custom_vehicles>

/*
    CUSTOM VEHICLES - open.mp / SA-MP 0.4DL

    Original GTA:SA / SA-MP vehicle model IDs are 400 through 611.
    This example puts the first custom vehicle at 612, then 613, 614, etc.

    Your current CustomVehicles component stores these new cars internally
    as models 19000, 19001, 19002, etc. The two ID sets point to the SAME
    vehicles. Players type /customveh 612, not /customveh 19000.

    Add a row to gVehicleList below for each new car. Keep the public IDs
    unique and greater than 611. Each row needs real DFF/TXD files inside
    Server/customvehs/. Do not use scriptfiles.

    Every function in custom_vehicles.inc:

    AddCustomVehicleModel(modelid, baseid, dff, txd)
        Register a new car. The base model supplies the driving behaviour.
    RemoveCustomVehicleModel(modelid)
        Unregister that car model when the filterscript unloads.
    IsCustomVehicleModelRegistered(modelid)
        Check whether the model is registered.
    GetCustomVehicleModelCount()
        Count all registered custom models.
    GetCustomVehicleTemplateModel(modelid)
        Get the original GTA model used as a base.

    LoadCustomVehicleModel(playerid, modelid)
        Send one custom model to one player.
    LoadAllCustomVehicles(playerid)
        Send every custom vehicle model to a player.
    IsCustomVehicleModelLoaded(playerid, modelid)
        Check whether that player finished downloading the car.

    CreateCustomVehicle(modelid, x, y, z, angle, color1, color2, siren)
        Create an actual custom car and return its vehicle ID.
    DestroyCustomVehicle(vehicleid)
        Delete a spawned custom car.
    IsCustomVehicle(vehicleid)
        Check whether a spawned vehicle uses a custom model.
    GetCustomVehicleModel(vehicleid)
        Get that car's registered model ID.
    GetCustomVehicleCount()
        Count currently spawned custom cars.
    GetPlayerCustomVehicle(playerid)
        Get the custom car the player is currently inside.

    SetSAMPWaterData("customvehs/water.dat")
        Register a custom water.dat file for player downloads.
    ClearSAMPWaterData()
        Remove the custom water.dat registration.
    IsSAMPWaterDataSet()
        Check whether replacement water data is registered.

    COMMANDS:
      /customveh 612     Create the first custom car beside you.
      /customveh 613     Create the second custom car beside you.
      /customveh list    Show the extra vehicles registered on this server.
      /vehlist           Same list, showing SA-MP's last original model.
      /vehload           Ask the server to send all registered models.
      /vehstatus         Show registration, downloads and your current car.
      /vehinfo           Show the model ID of the car you are sitting in.
      /deleteveh         Remove the last car you spawned with this script.
      /waterstatus       Check for replacement water data.
      /waterload         RCON admin: register customvehs/water.dat.
      /waterclear        RCON admin: remove this script's water.dat.

    The script registers the cars on startup, requests their files when a
    player connects, and spawns a selected car once that player's download
    is complete. The next /customveh command replaces their earlier car.
*/

#define LAST_ORIGINAL_VEHICLE (611)
#define FIRST_EXTRA_VEHICLE (612)
#define FIRST_COMPONENT_MODEL CUSTOM_VEHICLE_MODEL_MIN
#define MAX_COMPONENT_MODELS (CUSTOM_VEHICLE_MODEL_MAX - CUSTOM_VEHICLE_MODEL_MIN + 1)
#define VEHICLE_INFO_COLOR 0xB9EDFFFF
#define VEHICLE_ERROR_COLOR 0xFF8888FF
#define VEHICLE_CHECK_INTERVAL (1000)
#define DOWNLOAD_TIMEOUT (40)
#define CUSTOM_WATER_FILE "customvehs/water.dat"

enum CustomVehicleEntry
{
    PublicModelId,
    BaseModelId,
    ModelName[32],
    ModelDFF[64],
    ModelTXD[64]
};

// Add more custom cars by adding rows. These IDs appear in /vehlist.
// Each row points to actual files in Server/customvehs/. An example for vehicles could be GTA: LCS/VCS vehicles.
new const gVehicleList[][CustomVehicleEntry] =
{
    {612, 411, "Custom Infernus", "customvehs/612.dff", "customvehs/612.txd"},
    {613, 560, "Custom Sultan",  "customvehs/613.dff", "customvehs/613.txd"}
};

new bool:gModelRegistered[sizeof(gVehicleList)];
new gOwnedVehicle[MAX_PLAYERS];
new gOwnedModel[MAX_PLAYERS];
new gPendingModel[MAX_PLAYERS];
new gSecondsWaiting[MAX_PLAYERS];
new gModelTimer;
new bool:gWaterRegisteredByDemo;

forward CheckCustomVehicleDownloads();

stock ResetCustomVehiclePlayer(playerid)
{
    gOwnedVehicle[playerid] = INVALID_CUSTOM_VEHICLE_ID;
    gOwnedModel[playerid] = -1;
    gPendingModel[playerid] = -1;
    gSecondsWaiting[playerid] = 0;
    return 1;
}

stock GetCustomVehicleListIndex(publicModelId)
{
    for (new index = 0; index < sizeof(gVehicleList); index++)
    {
        if (gVehicleList[index][PublicModelId] == publicModelId)
        {
            return index;
        }
    }
    return -1;
}

stock GetInternalCustomVehicleModel(index)
{
    return FIRST_COMPONENT_MODEL + index;
}

stock GetPublicCustomVehicleModel(internalModelId)
{
    new index = internalModelId - FIRST_COMPONENT_MODEL;
    if (index < 0 || index >= sizeof(gVehicleList) || !gModelRegistered[index])
    {
        return -1;
    }
    return gVehicleList[index][PublicModelId];
}

stock bool:IsCustomVehicleCommand(const cmdtext[], const command[])
{
    new length = strlen(command);
    return !strcmp(cmdtext, command, true, length) &&
        (cmdtext[length] == ' ' || cmdtext[length] == '\0');
}

stock bool:ReadVehicleArgument(const cmdtext[], const command[], value[], valueSize)
{
    new index = strlen(command);
    while (cmdtext[index] == ' ')
    {
        index++;
    }
    if (cmdtext[index] == '\0')
    {
        value[0] = '\0';
        return false;
    }
    strmid(value, cmdtext, index, strlen(cmdtext), valueSize);
    return value[0] != '\0';
}

stock bool:ParseVehicleModelNumber(const input[], &modelid)
{
    modelid = 0;
    new length = strlen(input);
    if (length == 0 || length > 5)
    {
        return false;
    }
    for (new index = 0; index < length; index++)
    {
        if (input[index] < '0' || input[index] > '9')
        {
            return false;
        }
        modelid = modelid * 10 + (input[index] - '0');
    }
    return true;
}

stock DeletePlayerCustomVehicle(playerid)
{
    new vehicleid = gOwnedVehicle[playerid];
    new modelid = gOwnedModel[playerid];
    gOwnedVehicle[playerid] = INVALID_CUSTOM_VEHICLE_ID;
    gOwnedModel[playerid] = -1;

    if (vehicleid <= 0 || vehicleid == INVALID_VEHICLE_ID ||
        vehicleid == INVALID_CUSTOM_VEHICLE_ID || !IsCustomVehicle(vehicleid))
    {
        return 0;
    }
    if (GetCustomVehicleModel(vehicleid) != modelid)
    {
        return 0;
    }
    return DestroyCustomVehicle(vehicleid);
}

stock bool:PlayerCanSpawnCustomVehicle(playerid)
{
    if (GetPlayerState(playerid) != PLAYER_STATE_ONFOOT)
    {
        SendClientMessage(playerid, VEHICLE_ERROR_COLOR, "Leave your current vehicle before spawning another.");
        return false;
    }
    if (GetPlayerVirtualWorld(playerid) != 0 || GetPlayerInterior(playerid) != 0)
    {
        SendClientMessage(playerid, VEHICLE_ERROR_COLOR, "Spawn custom cars outdoors in world 0.");
        return false;
    }
    return true;
}

stock SpawnListedVehicle(playerid, index)
{
    if (!IsPlayerConnected(playerid) || index < 0 ||
        index >= sizeof(gVehicleList) || !gModelRegistered[index])
    {
        return 0;
    }
    if (!PlayerCanSpawnCustomVehicle(playerid))
    {
        return 0;
    }

    new internalModelId = GetInternalCustomVehicleModel(index);
    if (!IsCustomVehicleModelLoaded(playerid, internalModelId))
    {
        return 0;
    }

    new Float:x, Float:y, Float:z, Float:heading;
    GetPlayerPos(playerid, x, y, z);
    GetPlayerFacingAngle(playerid, heading);
    x += 6.0 * floatsin(-heading, degrees);
    y += 6.0 * floatcos(-heading, degrees);

    DeletePlayerCustomVehicle(playerid);

    new vehicleid = CreateCustomVehicle(
        internalModelId, x, y, z + 0.5, heading, 1, 1, false
    );
    if (vehicleid <= 0 || vehicleid == INVALID_VEHICLE_ID ||
        vehicleid == INVALID_CUSTOM_VEHICLE_ID || !IsCustomVehicle(vehicleid))
    {
        SendClientMessage(playerid, VEHICLE_ERROR_COLOR,
            "Could not create the vehicle. Check the server output and model files.");
        return 0;
    }

    gOwnedVehicle[playerid] = vehicleid;
    gOwnedModel[playerid] = internalModelId;

    new message[144];
    format(message, sizeof(message), "Spawned %s (model %d, vehicle %d).",
        gVehicleList[index][ModelName], gVehicleList[index][PublicModelId], vehicleid);
    SendClientMessage(playerid, VEHICLE_INFO_COLOR, message);
    return 1;
}

stock RequestListedVehicle(playerid, index)
{
    if (index < 0 || index >= sizeof(gVehicleList))
    {
        SendClientMessage(playerid, VEHICLE_ERROR_COLOR,
            "Vehicle not in the list. Type /vehlist to see available custom cars.");
        return 0;
    }
    if (!gModelRegistered[index] ||
        !IsCustomVehicleModelRegistered(GetInternalCustomVehicleModel(index)))
    {
        SendClientMessage(playerid, VEHICLE_ERROR_COLOR,
            "That vehicle has no valid DFF/TXD installed in customvehs/.");
        return 0;
    }
    if (!PlayerCanSpawnCustomVehicle(playerid))
    {
        return 0;
    }

    new modelid = GetInternalCustomVehicleModel(index);
    if (IsCustomVehicleModelLoaded(playerid, modelid))
    {
        gPendingModel[playerid] = -1;
        return SpawnListedVehicle(playerid, index);
    }

    if (!LoadCustomVehicleModel(playerid, modelid))
    {
        SendClientMessage(playerid, VEHICLE_ERROR_COLOR,
            "Could not start the vehicle download. Check the server output.");
        return 0;
    }

    gPendingModel[playerid] = index;
    gSecondsWaiting[playerid] = 0;
    SendClientMessage(playerid, VEHICLE_INFO_COLOR,
        "Downloading the vehicle. It will spawn automatically when ready.");
    return 1;
}

public CheckCustomVehicleDownloads()
{
    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++)
    {
        if (!IsPlayerConnected(playerid))
        {
            continue;
        }
        new index = gPendingModel[playerid];
        if (index < 0 || index >= sizeof(gVehicleList))
        {
            continue;
        }

        new modelid = GetInternalCustomVehicleModel(index);
        if (IsCustomVehicleModelLoaded(playerid, modelid))
        {
            gPendingModel[playerid] = -1;
            SpawnListedVehicle(playerid, index);
            continue;
        }

        gSecondsWaiting[playerid]++;
        if (gSecondsWaiting[playerid] >= DOWNLOAD_TIMEOUT)
        {
            gPendingModel[playerid] = -1;
            SendClientMessage(playerid, VEHICLE_ERROR_COLOR,
                "Vehicle download timed out. Use /vehload and /customveh again.");
            continue;
        }
        if (gSecondsWaiting[playerid] % 5 == 0)
        {
            LoadCustomVehicleModel(playerid, modelid);
        }
    }
    return 1;
}

public OnFilterScriptInit()
{
    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++)
    {
        ResetCustomVehiclePlayer(playerid);
    }

    for (new index = 0; index < sizeof(gVehicleList); index++)
    {
        new publicid = gVehicleList[index][PublicModelId];
        new modelid = GetInternalCustomVehicleModel(index);

        if (publicid < FIRST_EXTRA_VEHICLE ||
            GetCustomVehicleListIndex(publicid) != index)
        {
            printf("[CustomVehicles] Duplicate or invalid public vehicle ID %d.", publicid);
            continue;
        }

        gModelRegistered[index] = AddCustomVehicleModel(modelid,
            gVehicleList[index][BaseModelId],
            gVehicleList[index][ModelDFF], gVehicleList[index][ModelTXD]);

        if (gModelRegistered[index])
        {
            printf("[CustomVehicles] Added vehicle %d: %s (base model %d).",
                publicid, gVehicleList[index][ModelName],
                GetCustomVehicleTemplateModel(modelid));
        }
        else
        {
            printf("[CustomVehicles] Cannot register %d: check %s and %s.",
                publicid, gVehicleList[index][ModelDFF],
                gVehicleList[index][ModelTXD]);
        }
    }

    gModelTimer = SetTimer("CheckCustomVehicleDownloads", VEHICLE_CHECK_INTERVAL, true);
    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++)
    {
        if (IsPlayerConnected(playerid))
        {
            LoadAllCustomVehicles(playerid);
        }
    }
    print("[CustomVehicles] /customveh 612 /customveh 613 /vehlist");
    return 1;
}

public OnFilterScriptExit()
{
    if (gModelTimer != 0)
    {
        KillTimer(gModelTimer);
    }
    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++)
    {
        DeletePlayerCustomVehicle(playerid);
        ResetCustomVehiclePlayer(playerid);
    }
    for (new index = 0; index < sizeof(gVehicleList); index++)
    {
        if (gModelRegistered[index])
        {
            RemoveCustomVehicleModel(GetInternalCustomVehicleModel(index));
        }
    }
    if (gWaterRegisteredByDemo)
    {
        ClearSAMPWaterData();
    }
    return 1;
}

public OnPlayerConnect(playerid)
{
    ResetCustomVehiclePlayer(playerid);
    LoadAllCustomVehicles(playerid);
    return 1;
}

public OnPlayerSpawn(playerid)
{
    LoadAllCustomVehicles(playerid);
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    DeletePlayerCustomVehicle(playerid);
    ResetCustomVehiclePlayer(playerid);
    #pragma unused reason
    return 1;
}

public OnVehicleDeath(vehicleid, killerid)
{
    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++)
    {
        if (gOwnedVehicle[playerid] == vehicleid)
        {
            gOwnedVehicle[playerid] = INVALID_CUSTOM_VEHICLE_ID;
            gOwnedModel[playerid] = -1;
        }
    }
    #pragma unused killerid
    return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
    if (IsCustomVehicleCommand(cmdtext, "/vehhelp"))
    {
        SendClientMessage(playerid, VEHICLE_INFO_COLOR,
            "/customveh ID /customveh list /vehlist /vehload /vehinfo /vehstatus");
        SendClientMessage(playerid, VEHICLE_INFO_COLOR,
            "/deleteveh /waterstatus /waterload /waterclear");
        return 1;
    }

    if (IsCustomVehicleCommand(cmdtext, "/customveh"))
    {
        new argument[24];
        new publicid;
        if (!ReadVehicleArgument(cmdtext, "/customveh", argument, sizeof(argument)))
        {
            SendClientMessage(playerid, VEHICLE_ERROR_COLOR, "Usage: /customveh 612");
            return 1;
        }
        if (!strcmp(argument, "list", true))
        {
            // Listing is also available as /vehlist below.
            SendClientMessage(playerid, VEHICLE_INFO_COLOR, "Custom vehicles start at 612. Type /vehlist for the full list.");
            for (new index = 0; index < sizeof(gVehicleList); index++)
            {
                new message[144];
                format(message, sizeof(message), "%d: %s | Base %d | Installed %d",
                    gVehicleList[index][PublicModelId], gVehicleList[index][ModelName],
                    gVehicleList[index][BaseModelId], gModelRegistered[index]);
                SendClientMessage(playerid, VEHICLE_INFO_COLOR, message);
            }
            return 1;
        }
        if (!ParseVehicleModelNumber(argument, publicid))
        {
            SendClientMessage(playerid, VEHICLE_ERROR_COLOR, "Enter a number, such as /customveh 612.");
            return 1;
        }
        if (publicid <= LAST_ORIGINAL_VEHICLE)
        {
            SendClientMessage(playerid, VEHICLE_ERROR_COLOR, "Original vehicle IDs end at 611. Custom vehicles start at 612.");
            return 1;
        }
        RequestListedVehicle(playerid, GetCustomVehicleListIndex(publicid));
        return 1;
    }

    if (IsCustomVehicleCommand(cmdtext, "/vehlist"))
    {
        SendClientMessage(playerid, VEHICLE_INFO_COLOR,
            "Original GTA/SA-MP vehicle IDs: 400-611 | Extra vehicles:");
        for (new index = 0; index < sizeof(gVehicleList); index++)
        {
            new message[144];
            format(message, sizeof(message), "%d: %s | Base %d | Installed %d",
                gVehicleList[index][PublicModelId], gVehicleList[index][ModelName],
                gVehicleList[index][BaseModelId], gModelRegistered[index]);
            SendClientMessage(playerid, VEHICLE_INFO_COLOR, message);
        }
        return 1;
    }

    if (IsCustomVehicleCommand(cmdtext, "/vehload"))
    {
        if (LoadAllCustomVehicles(playerid))
        {
            SendClientMessage(playerid, VEHICLE_INFO_COLOR,
                "All registered custom vehicle files have been requested.");
        }
        else
        {
            SendClientMessage(playerid, VEHICLE_ERROR_COLOR,
                "Could not request the vehicle files.");
        }
        return 1;
    }

    if (IsCustomVehicleCommand(cmdtext, "/deleteveh"))
    {
        gPendingModel[playerid] = -1;
        SendClientMessage(playerid, VEHICLE_INFO_COLOR,
            DeletePlayerCustomVehicle(playerid) ? "Your custom vehicle was deleted." :
            "You have no custom vehicle to delete.");
        return 1;
    }

    if (IsCustomVehicleCommand(cmdtext, "/vehstatus"))
    {
        new message[144];
        format(message, sizeof(message),
            "Custom models: %d | Spawned cars: %d | Your car: %d | Waiting: %d",
            GetCustomVehicleModelCount(), GetCustomVehicleCount(),
            gOwnedVehicle[playerid], gPendingModel[playerid] >= 0);
        SendClientMessage(playerid, VEHICLE_INFO_COLOR, message);
        for (new index = 0; index < sizeof(gVehicleList); index++)
        {
            format(message, sizeof(message),
                "Model %d: Registered %d | Your files downloaded %d",
                gVehicleList[index][PublicModelId], gModelRegistered[index],
                IsCustomVehicleModelLoaded(playerid, GetInternalCustomVehicleModel(index)));
            SendClientMessage(playerid, VEHICLE_INFO_COLOR, message);
        }
        return 1;
    }

    if (IsCustomVehicleCommand(cmdtext, "/vehinfo"))
    {
        new vehicleid = GetPlayerCustomVehicle(playerid);
        if (vehicleid <= 0 || vehicleid == INVALID_VEHICLE_ID ||
            vehicleid == INVALID_CUSTOM_VEHICLE_ID || !IsCustomVehicle(vehicleid))
        {
            SendClientMessage(playerid, VEHICLE_ERROR_COLOR, "Sit inside a custom vehicle first.");
            return 1;
        }
        new internalModelId = GetCustomVehicleModel(vehicleid);
        new publicModelId = GetPublicCustomVehicleModel(internalModelId);
        new message[144];
        format(message, sizeof(message),
            "Vehicle ID: %d | Custom model: %d | Original base model: %d",
            vehicleid, publicModelId, GetCustomVehicleTemplateModel(internalModelId));
        SendClientMessage(playerid, VEHICLE_INFO_COLOR, message);
        return 1;
    }

    if (IsCustomVehicleCommand(cmdtext, "/waterstatus"))
    {
        SendClientMessage(playerid, VEHICLE_INFO_COLOR,
            IsSAMPWaterDataSet() ? "Replacement water data is registered." :
            "No replacement water file is registered.");
        return 1;
    }

    if (IsCustomVehicleCommand(cmdtext, "/waterload"))
    {
        if (!IsPlayerAdmin(playerid))
        {
            SendClientMessage(playerid, VEHICLE_ERROR_COLOR, "RCON admins only.");
            return 1;
        }
        if (IsSAMPWaterDataSet() && !gWaterRegisteredByDemo)
        {
            SendClientMessage(playerid, VEHICLE_ERROR_COLOR,
                "Another script already registered replacement water data.");
            return 1;
        }
        if (SetSAMPWaterData(CUSTOM_WATER_FILE))
        {
            gWaterRegisteredByDemo = true;
            SendClientMessage(playerid, VEHICLE_INFO_COLOR,
                "customvehs/water.dat registered. Clients apply it on next launch.");
        }
        else
        {
            SendClientMessage(playerid, VEHICLE_ERROR_COLOR,
                "Cannot open customvehs/water.dat from the server folder.");
        }
        return 1;
    }

    if (IsCustomVehicleCommand(cmdtext, "/waterclear"))
    {
        if (!IsPlayerAdmin(playerid))
        {
            SendClientMessage(playerid, VEHICLE_ERROR_COLOR, "RCON admins only.");
            return 1;
        }
        if (!gWaterRegisteredByDemo)
        {
            SendClientMessage(playerid, VEHICLE_ERROR_COLOR,
                "This filterscript did not register the replacement water file.");
            return 1;
        }
        if (ClearSAMPWaterData())
        {
            gWaterRegisteredByDemo = false;
            SendClientMessage(playerid, VEHICLE_INFO_COLOR, "Custom water was removed.");
        }
        else
        {
            SendClientMessage(playerid, VEHICLE_ERROR_COLOR, "Could not remove custom water data.");
        }
        return 1;
    }
    return 0;
}
