#define FILTERSCRIPT
#include <open.mp>
#include <custom_animations>

// CUSTOM ANIMATIONS - open.mp / SA-MP 0.4DL
//
// Put M2PED.ifp in: Server/customifp/M2PED.ifp
// File paths start at the server folder. Do not use scriptfiles.
//
// Every function in custom_animations.inc:
//
// AddIFPAnimation(library, file)                 Register an IFP file.
// RemoveIFPAnimation(library)                    Remove an IFP registration.
// IsIFPAnimationRegistered(library)              Check that the library exists.
// GetIFPAnimationCount()                         Count registered IFP libraries.
// LoadIFPAnimation(playerid, library)            Send an IFP to one player.
// LoadAllIFPAnimations(playerid)                 Send every registered IFP.
// IsCustomAnimationLoaded(playerid, library)     Check that the download finished.
//
// PlayIFPAnimationForPlayer(viewer, actor, library, clip, 4.1, false)
// Play a clip once. Set false to true to keep playing it.
// PlayCustomAnimationForPlayer(viewer, actor, library, clip, 4.1)
// Play a clip once for one viewer.
// LoopCustomAnimationForPlayer(viewer, actor, library, clip, 4.1)
// Loop a clip for one viewer.
// PlayCustomAnimation(actor, library, clip, 4.1)
// Play once for all connected players.
// LoopCustomAnimation(actor, library, clip, 4.1)
// Loop for all connected players.
// SendCustomAnimationToAll(actor, library, clip, 4.1, true)
// Send a clip to all players. True repeats; false plays once.
//
// QueueCustomAnimationForPlayer(viewer, actor, library, clip, 4.1)
// Add the next clip for one viewer.
// QueueCustomAnimation(actor, library, clip, 4.1)
// Add the next clip for all viewers.
// ClearCustomAnimationQueueForPlayer(viewer, actor)
// Empty the queue for one viewer.
// ClearCustomAnimationQueue(actor)               Empty the queue for everyone.
// GetCustomAnimationQueueCount(viewer, actor)    Count queued clips.
//
// StopCustomAnimationForPlayer(viewer, actor, 4.1)
// StopCustomAnimation(actor, 4.1)                Finish playing the clip.
// CancelCustomAnimationForPlayer(viewer, actor, 4.1)
// CancelCustomAnimation(actor, 4.1)              Cancel playback.
// PauseCustomAnimationForPlayer(viewer, actor)
// PauseCustomAnimation(actor)                    Pause playback.
// ResumeCustomAnimationForPlayer(viewer, actor)
// ResumeCustomAnimation(actor)                   Continue playback.
// SetCustomAnimationSpeedForPlayer(viewer, actor, speed)
// SetCustomAnimationSpeed(actor, speed)          Set playback speed.
// GetCustomAnimationSpeed(viewer, actor)         Read playback speed.
// GetCustomAnimationState(viewer, actor)         Read PLAYING/LOOPING/PAUSED flags.
// IsCustomAnimationPlaying(viewer, actor)        Check for playback.
// IsCustomAnimationPaused(viewer, actor)         Check for a pause.
//
// CustomAnimationsRequired()                     Check client requirement.
// IsCustomAnimationsInstallPromptEnabled()      Read install-prompt setting.
// SetCustomAnimationsInstallPromptEnabled(bool) Change install-prompt setting.
// GetCustomAnimationsClientProtocolVersion()    Read client protocol number.
//
// THIS EXAMPLE:
// 1. The server registers M2PED.ifp when this script loads.
// 2. Each player downloads that IFP.
// 3. When a player holds sprint and moves, the script plays the
// "sprint" clip from M2PED.ifp on that player, for everyone nearby.
// 4. Releasing sprint stops that clip. Joining players see active loops.
// 5. /animtest plays a custom clip once. /animplay CLIP lets you test
// any animation name stored inside M2PED.ifp.
//
// COMMANDS:
// /animsprint 1        Use M2PED's sprint clip while running (default).
// /animsprint 0        Turn off the replacement sprint.
// /animtest            Play the M2PED sprint clip once for a simple test.
// /animtest CLIP       Play the named clip once.
// /animplay CLIP       Play the named clip once.
// /animloop CLIP       Loop the named clip.
// /animqueue CLIP      Queue another clip after your current clip.
// /animstop            Stop a test or loop and return to sprint mode.
// /animcancel          Cancel playback and return to sprint mode.
// /animclear           Remove queued clips.
// /animpause           Pause the current clip.
// /animresume          Continue a paused clip.
// /animspeed 0.5       Set playback speed to half.
// /animspeed 1.0       Restore normal speed.
// /animstatus          Display download, animation and sprint information.
// /animload            Request the M2PED IFP download again.
// /animresync          Send the current clip to nearby viewers again.
// /animprompt 0|1      RCON admin: change the client install prompt.
//
// M2PED_SPRINT_CLIP is the clip name inside M2PED.ifp. Change it if your
// copy uses a different name. This script does not rename IFP clips.

#define M2PED_LIBRARY "M2PED" // This is a Mafia 2 animation example
#define M2PED_FILE "customifp/M2PED.ifp"
#define M2PED_SPRINT_CLIP "sprint"
#define ANIMATION_NAME_SIZE (64)
#define ANIMATION_CHECK_INTERVAL (250)
#define ANIMATION_INFO_COLOR 0xB9EDFFFF
#define ANIMATION_ERROR_COLOR 0xFF8888FF

#define ANIM_MODE_NONE (0)
#define ANIM_MODE_SPRINT (1)
#define ANIM_MODE_MANUAL (2)

new bool:gM2PedRegistered;
new gAnimationTimer;
new gAnimationChecks;
new bool:gSprintEnabled[MAX_PLAYERS];
new bool:gManualControl[MAX_PLAYERS];
new bool:gLibraryReady[MAX_PLAYERS];
new gAnimationMode[MAX_PLAYERS];
new bool:gAnimationLoop[MAX_PLAYERS];
new gAnimationName[MAX_PLAYERS][ANIMATION_NAME_SIZE];

forward CheckCustomAnimations();

stock ResetAnimationPlayer(playerid)
{
    gSprintEnabled[playerid] = true;
    gManualControl[playerid] = false;
    gLibraryReady[playerid] = false;
    gAnimationMode[playerid] = ANIM_MODE_NONE;
    gAnimationLoop[playerid] = false;
    gAnimationName[playerid][0] = '\0';
    return 1;
}

stock bool:IsAnimationCommand(const cmdtext[], const command[])
{
    new length = strlen(command);
    return !strcmp(cmdtext, command, true, length) &&
        (cmdtext[length] == ' ' || cmdtext[length] == '\0');
}

stock bool:GetAnimationArgument(const cmdtext[], const command[], result[], resultSize)
{
    new index = strlen(command);
    while (cmdtext[index] == ' ')
    {
        index++;
    }
    if (cmdtext[index] == '\0')
    {
        result[0] = '\0';
        return false;
    }
    strmid(result, cmdtext, index, strlen(cmdtext), resultSize);
    return result[0] != '\0';
}

stock RequestAnimationFile(playerid)
{
    if (!gM2PedRegistered || !IsPlayerConnected(playerid))
    {
        return 0;
    }
    return LoadIFPAnimation(playerid, M2PED_LIBRARY);
}

stock SendCurrentAnimationToViewer(actorid, viewerid)
{
    if (!gM2PedRegistered || !IsPlayerConnected(actorid) ||
        !IsPlayerConnected(viewerid) || gAnimationMode[actorid] == ANIM_MODE_NONE)
    {
        return 0;
    }
    if (viewerid != actorid && !IsPlayerStreamedIn(actorid, viewerid))
    {
        return 0;
    }
    if (!IsCustomAnimationLoaded(viewerid, M2PED_LIBRARY))
    {
        RequestAnimationFile(viewerid);
        return 0;
    }
    return PlayIFPAnimationForPlayer(
        viewerid, actorid, M2PED_LIBRARY, gAnimationName[actorid],
        4.1, gAnimationLoop[actorid]
    );
}

stock SendCurrentAnimationToAll(actorid)
{
    new viewers = 0;
    for (new viewerid = 0; viewerid < MAX_PLAYERS; viewerid++)
    {
        if (SendCurrentAnimationToViewer(actorid, viewerid))
        {
            viewers++;
        }
    }
    return viewers;
}

stock SyncAnimationsForViewer(viewerid)
{
    if (!IsPlayerConnected(viewerid))
    {
        return 0;
    }
    new sent = 0;
    for (new actorid = 0; actorid < MAX_PLAYERS; actorid++)
    {
        if (SendCurrentAnimationToViewer(actorid, viewerid))
        {
            sent++;
        }
    }
    return sent;
}

stock StartPlayerCustomAnimation(playerid, const clip[], bool:loop, animationMode)
{
    if (!gM2PedRegistered || !IsPlayerConnected(playerid))
    {
        return 0;
    }

    ClearCustomAnimationQueue(playerid);
    StopCustomAnimation(playerid);

    format(gAnimationName[playerid], ANIMATION_NAME_SIZE, "%s", clip);
    gAnimationLoop[playerid] = loop;
    gAnimationMode[playerid] = animationMode;

    // Send to players whose IFP has arrived. The timer handles late downloads.
    return SendCurrentAnimationToAll(playerid);
}

stock StopPlayerCustomAnimation(playerid)
{
    if (gAnimationMode[playerid] == ANIM_MODE_NONE)
    {
        return 0;
    }
    gAnimationMode[playerid] = ANIM_MODE_NONE;
    gAnimationLoop[playerid] = false;
    gAnimationName[playerid][0] = '\0';
    ClearCustomAnimationQueue(playerid);
    return StopCustomAnimation(playerid);
}

stock bool:IsPlayerUsingSprint(playerid)
{
    if (!gSprintEnabled[playerid] || gManualControl[playerid] ||
        GetPlayerState(playerid) != PLAYER_STATE_ONFOOT ||
        GetPlayerSpecialAction(playerid) == SPECIAL_ACTION_DUCK)
    {
        return false;
    }

    new KEY:keys, updown, leftright;
    GetPlayerKeys(playerid, keys, updown, leftright);
    return ((_:keys & _:KEY_SPRINT) != 0) && (updown != 0 || leftright != 0);
}

public CheckCustomAnimations()
{
    if (!gM2PedRegistered)
    {
        return 1;
    }

    gAnimationChecks++;
    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++)
    {
        if (!IsPlayerConnected(playerid))
        {
            continue;
        }

        // Download completion is checked every second, not every frame.
        if (gAnimationChecks % 4 == 0)
        {
            new bool:ready = IsCustomAnimationLoaded(playerid, M2PED_LIBRARY);
            if (ready && !gLibraryReady[playerid])
            {
                gLibraryReady[playerid] = true;
                SyncAnimationsForViewer(playerid);
            }
            else if (!ready)
            {
                gLibraryReady[playerid] = false;
                if (gAnimationChecks % 20 == 0)
                {
                    RequestAnimationFile(playerid);
                }
            }
        }

        if (IsPlayerUsingSprint(playerid))
        {
            if (gAnimationMode[playerid] != ANIM_MODE_SPRINT)
            {
                StartPlayerCustomAnimation(playerid, M2PED_SPRINT_CLIP,
                    true, ANIM_MODE_SPRINT);
            }
        }
        else if (gAnimationMode[playerid] == ANIM_MODE_SPRINT)
        {
            StopPlayerCustomAnimation(playerid);
        }
    }
    return 1;
}

public OnFilterScriptInit()
{
    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++)
    {
        ResetAnimationPlayer(playerid);
    }

    gM2PedRegistered = AddIFPAnimation(M2PED_LIBRARY, M2PED_FILE);
    if (gM2PedRegistered)
    {
        printf("[CustomAnimations] Loaded %s (%d IFP libraries).",
            M2PED_FILE, GetIFPAnimationCount());
    }
    else
    {
        printf("[CustomAnimations] Cannot open %s.", M2PED_FILE);
    }

    gAnimationTimer = SetTimer("CheckCustomAnimations", ANIMATION_CHECK_INTERVAL, true);
    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++)
    {
        if (IsPlayerConnected(playerid))
        {
            RequestAnimationFile(playerid);
        }
    }
    return 1;
}

public OnFilterScriptExit()
{
    if (gAnimationTimer != 0)
    {
        KillTimer(gAnimationTimer);
    }
    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++)
    {
        if (IsPlayerConnected(playerid))
        {
            StopPlayerCustomAnimation(playerid);
        }
    }
    if (gM2PedRegistered)
    {
        RemoveIFPAnimation(M2PED_LIBRARY);
    }
    return 1;
}

public OnPlayerConnect(playerid)
{
    ResetAnimationPlayer(playerid);
    RequestAnimationFile(playerid);
    return 1;
}

public OnPlayerSpawn(playerid)
{
    gManualControl[playerid] = false;
    StopPlayerCustomAnimation(playerid);
    RequestAnimationFile(playerid);
    return 1;
}

public OnPlayerStreamIn(playerid, forplayerid)
{
    SendCurrentAnimationToViewer(playerid, forplayerid);
    return 1;
}

public OnPlayerDeath(playerid, killerid, WEAPON:reason)
{
    StopPlayerCustomAnimation(playerid);
    gManualControl[playerid] = false;
    #pragma unused killerid
    #pragma unused reason
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    StopPlayerCustomAnimation(playerid);
    ResetAnimationPlayer(playerid);
    #pragma unused reason
    return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
    if (IsAnimationCommand(cmdtext, "/animhelp"))
    {
        SendClientMessage(playerid, ANIMATION_INFO_COLOR,
            "/animsprint 1|0 /animtest [CLIP] /animplay CLIP /animloop CLIP");
        SendClientMessage(playerid, ANIMATION_INFO_COLOR,
            "/animqueue CLIP /animstop /animcancel /animclear /animpause /animresume");
        SendClientMessage(playerid, ANIMATION_INFO_COLOR,
            "/animspeed 0.5 /animstatus /animload /animresync /animprompt 0|1");
        return 1;
    }

    if (IsAnimationCommand(cmdtext, "/animsprint"))
    {
        new value[16];
        if (!GetAnimationArgument(cmdtext, "/animsprint", value, sizeof(value)) ||
            (strcmp(value, "0") != 0 && strcmp(value, "1") != 0))
        {
            SendClientMessage(playerid, ANIMATION_ERROR_COLOR, "Usage: /animsprint 1 or /animsprint 0");
            return 1;
        }
        gSprintEnabled[playerid] = value[0] == '1';
        if (!gSprintEnabled[playerid] && gAnimationMode[playerid] == ANIM_MODE_SPRINT)
        {
            StopPlayerCustomAnimation(playerid);
        }
        SendClientMessage(playerid, ANIMATION_INFO_COLOR,
            gSprintEnabled[playerid] ? "M2PED sprint is enabled." : "M2PED sprint is disabled.");
        return 1;
    }

    if (IsAnimationCommand(cmdtext, "/animload"))
    {
        if (gM2PedRegistered && LoadAllIFPAnimations(playerid))
        {
            SendClientMessage(playerid, ANIMATION_INFO_COLOR, "M2PED.ifp download requested.");
        }
        else
        {
            SendClientMessage(playerid, ANIMATION_ERROR_COLOR, "Cannot download customifp/M2PED.ifp.");
        }
        return 1;
    }

    if (IsAnimationCommand(cmdtext, "/animtest") ||
        IsAnimationCommand(cmdtext, "/animplay") ||
        IsAnimationCommand(cmdtext, "/animloop"))
    {
        new bool:loop = IsAnimationCommand(cmdtext, "/animloop");
        new bool:test = IsAnimationCommand(cmdtext, "/animtest");
        new clip[ANIMATION_NAME_SIZE];

        if (test)
        {
            if (!GetAnimationArgument(cmdtext, "/animtest", clip, sizeof(clip)))
            {
                format(clip, sizeof(clip), "%s", M2PED_SPRINT_CLIP);
            }
        }
        else if (loop)
        {
            if (!GetAnimationArgument(cmdtext, "/animloop", clip, sizeof(clip)))
            {
                SendClientMessage(playerid, ANIMATION_ERROR_COLOR, "Usage: /animloop CLIP");
                return 1;
            }
        }
        else if (!GetAnimationArgument(cmdtext, "/animplay", clip, sizeof(clip)))
        {
            SendClientMessage(playerid, ANIMATION_ERROR_COLOR, "Usage: /animplay CLIP");
            return 1;
        }

        if (!gM2PedRegistered)
        {
            SendClientMessage(playerid, ANIMATION_ERROR_COLOR,
                "M2PED.ifp was not registered. Check the file in customifp/.");
            return 1;
        }
        if (!IsCustomAnimationLoaded(playerid, M2PED_LIBRARY))
        {
            RequestAnimationFile(playerid);
            SendClientMessage(playerid, ANIMATION_ERROR_COLOR,
                "M2PED.ifp is still downloading. Try the command again when ready.");
            return 1;
        }

        gManualControl[playerid] = true;
        new viewers = StartPlayerCustomAnimation(playerid, clip, loop, ANIM_MODE_MANUAL);
        new message[144];
        format(message, sizeof(message), "%s: %s (%d player(s) received it).",
            loop ? "Looping" : "Playing", clip, viewers);
        SendClientMessage(playerid, ANIMATION_INFO_COLOR, message);
        return 1;
    }

    if (IsAnimationCommand(cmdtext, "/animqueue"))
    {
        new clip[ANIMATION_NAME_SIZE];
        if (!GetAnimationArgument(cmdtext, "/animqueue", clip, sizeof(clip)))
        {
            SendClientMessage(playerid, ANIMATION_ERROR_COLOR, "Usage: /animqueue CLIP");
            return 1;
        }
        if (gAnimationMode[playerid] != ANIM_MODE_MANUAL)
        {
            SendClientMessage(playerid, ANIMATION_ERROR_COLOR, "Use /animplay CLIP first.");
            return 1;
        }
        new viewers = QueueCustomAnimation(playerid, M2PED_LIBRARY, clip);
        new message[96];
        format(message, sizeof(message), "Queued %s for %d player(s).", clip, viewers);
        SendClientMessage(playerid, ANIMATION_INFO_COLOR, message);
        return 1;
    }

    if (IsAnimationCommand(cmdtext, "/animstop") ||
        IsAnimationCommand(cmdtext, "/animcancel"))
    {
        new bool:cancel = IsAnimationCommand(cmdtext, "/animcancel");
        gManualControl[playerid] = false;
        if (cancel)
        {
            ClearCustomAnimationQueue(playerid);
            CancelCustomAnimation(playerid);
            gAnimationMode[playerid] = ANIM_MODE_NONE;
            gAnimationName[playerid][0] = '\0';
        }
        else
        {
            StopPlayerCustomAnimation(playerid);
        }
        SendClientMessage(playerid, ANIMATION_INFO_COLOR, "Animation ended. Sprint is available again.");
        return 1;
    }

    if (IsAnimationCommand(cmdtext, "/animclear"))
    {
        new cleared = ClearCustomAnimationQueue(playerid);
        new message[96];
        format(message, sizeof(message), "Cleared queued animations for %d player(s).", cleared);
        SendClientMessage(playerid, ANIMATION_INFO_COLOR, message);
        return 1;
    }

    if (IsAnimationCommand(cmdtext, "/animpause") ||
        IsAnimationCommand(cmdtext, "/animresume"))
    {
        new bool:pause = IsAnimationCommand(cmdtext, "/animpause");
        new viewers = pause ? PauseCustomAnimation(playerid) : ResumeCustomAnimation(playerid);
        new message[96];
        format(message, sizeof(message), "%s to %d player(s).",
            pause ? "Paused" : "Resumed", viewers);
        SendClientMessage(playerid, ANIMATION_INFO_COLOR, message);
        return 1;
    }

    if (IsAnimationCommand(cmdtext, "/animspeed"))
    {
        new value[24];
        if (!GetAnimationArgument(cmdtext, "/animspeed", value, sizeof(value)))
        {
            SendClientMessage(playerid, ANIMATION_ERROR_COLOR, "Usage: /animspeed 0.5 (range 0.25-3.0)");
            return 1;
        }
        new Float:speed = floatstr(value);
        if (speed < 0.25 || speed > 3.0)
        {
            SendClientMessage(playerid, ANIMATION_ERROR_COLOR, "Speed must be between 0.25 and 3.0.");
            return 1;
        }
        new viewers = SetCustomAnimationSpeed(playerid, speed);
        new message[96];
        format(message, sizeof(message), "Speed %.2f sent to %d player(s).", speed, viewers);
        SendClientMessage(playerid, ANIMATION_INFO_COLOR, message);
        return 1;
    }

    if (IsAnimationCommand(cmdtext, "/animresync"))
    {
        new viewers = SendCurrentAnimationToAll(playerid);
        new message[96];
        format(message, sizeof(message), "Animation sent to %d player(s).", viewers);
        SendClientMessage(playerid, ANIMATION_INFO_COLOR, message);
        return 1;
    }

    if (IsAnimationCommand(cmdtext, "/animstatus"))
    {
        new message[144];
        format(message, sizeof(message),
            "M2PED registered: %d | Downloaded: %d | Libraries: %d | Sprint: %d",
            IsIFPAnimationRegistered(M2PED_LIBRARY),
            IsCustomAnimationLoaded(playerid, M2PED_LIBRARY),
            GetIFPAnimationCount(), gSprintEnabled[playerid]);
        SendClientMessage(playerid, ANIMATION_INFO_COLOR, message);

        new animationFlags = GetCustomAnimationState(playerid, playerid);
        format(message, sizeof(message),
            "Playing: %d | Loop: %d | Paused: %d | Speed: %.2f | Queue: %d",
            IsCustomAnimationPlaying(playerid, playerid),
            (animationFlags & CUSTOM_ANIMATION_STATE_LOOPING) != 0,
            IsCustomAnimationPaused(playerid, playerid),
            GetCustomAnimationSpeed(playerid, playerid),
            GetCustomAnimationQueueCount(playerid, playerid));
        SendClientMessage(playerid, ANIMATION_INFO_COLOR, message);

        format(message, sizeof(message),
            "Client required: %d | Protocol: %d | Install prompt: %d",
            CustomAnimationsRequired(), GetCustomAnimationsClientProtocolVersion(),
            IsCustomAnimationsInstallPromptEnabled());
        SendClientMessage(playerid, ANIMATION_INFO_COLOR, message);
        return 1;
    }

    if (IsAnimationCommand(cmdtext, "/animprompt"))
    {
        if (!IsPlayerAdmin(playerid))
        {
            SendClientMessage(playerid, ANIMATION_ERROR_COLOR, "RCON admins only.");
            return 1;
        }
        new value[16];
        if (!GetAnimationArgument(cmdtext, "/animprompt", value, sizeof(value)) ||
            (strcmp(value, "0") != 0 && strcmp(value, "1") != 0))
        {
            SendClientMessage(playerid, ANIMATION_ERROR_COLOR, "Usage: /animprompt 0 or /animprompt 1");
            return 1;
        }
        new bool:enable = value[0] == '1';
        if (SetCustomAnimationsInstallPromptEnabled(enable))
        {
            SendClientMessage(playerid, ANIMATION_INFO_COLOR,
                enable ? "Client install prompt enabled." : "Client install prompt disabled.");
        }
        else
        {
            SendClientMessage(playerid, ANIMATION_ERROR_COLOR, "Could not change install prompt.");
        }
        return 1;
    }

    return 0;
}
