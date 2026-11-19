#if defined _custom_animations_included
    #endinput
#endif
#define _custom_animations_included

// Pawn 3.x identifiers are limited to 31 characters. Keep public spellings
// through preprocessing and bind short native names without truncation.
#define ClearCustomAnimationQueueForPlayer ClearCustomAnimQueueForPlayer
#define SetCustomAnimationSpeedForPlayer SetCustomAnimSpeedForPlayer
#define IsCustomAnimationsInstallPromptEnabled IsCustomAnimPromptEnabled
#define SetCustomAnimationsInstallPromptEnabled SetCustomAnimPromptEnabled
#define GetCustomAnimationsClientProtocolVersion GetCustomAnimProtocolVersion


native bool:AddIFPAnimation(const library[], const filename[]);
native bool:RemoveIFPAnimation(const library[]);
native bool:IsIFPAnimationRegistered(const library[]);
native GetIFPAnimationCount();

native bool:LoadIFPAnimation(playerid, const library[]);
native bool:LoadAllIFPAnimations(playerid);

native bool:PlayIFPAnimationForPlayer(
    receiverid,
    subjectid,
    const library[],
    const animation[],
    Float:blendDelta = 4.1,
    bool:loop = false
);

native bool:QueueCustomAnimationForPlayer(
    receiverid,
    subjectid,
    const library[],
    const animation[],
    Float:blendDelta = 4.1
);
native bool:ClearCustomAnimationQueueForPlayer(receiverid, subjectid);

native bool:StopCustomAnimationForPlayer(receiverid, subjectid, Float:blendDelta = 4.1);

native bool:CancelCustomAnimationForPlayer(receiverid, subjectid, Float:blendDelta = 4.1);
native bool:PauseCustomAnimationForPlayer(receiverid, subjectid);
native bool:ResumeCustomAnimationForPlayer(receiverid, subjectid);
native bool:SetCustomAnimationSpeedForPlayer(receiverid, subjectid, Float:speed);

#define CUSTOM_ANIMATION_STATE_PLAYING (1)
#define CUSTOM_ANIMATION_STATE_LOOPING (2)
#define CUSTOM_ANIMATION_STATE_PAUSED  (4)
native bool:IsCustomAnimationLoaded(playerid, const library[]);
native GetCustomAnimationState(receiverid, subjectid);
native bool:IsCustomAnimationPlaying(receiverid, subjectid);
native bool:IsCustomAnimationPaused(receiverid, subjectid);
native Float:GetCustomAnimationSpeed(receiverid, subjectid);

stock bool:PlayCustomAnimationForPlayer(receiverid, subjectid, const library[], const animation[], Float:blendDelta = 4.1)
{
    return PlayIFPAnimationForPlayer(receiverid, subjectid, library, animation, blendDelta, false);
}

stock bool:LoopCustomAnimationForPlayer(receiverid, subjectid, const library[], const animation[], Float:blendDelta = 4.1)
{
    return PlayIFPAnimationForPlayer(receiverid, subjectid, library, animation, blendDelta, true);
}

stock QueueCustomAnimation(subjectid, const library[], const animation[], Float:blendDelta = 4.1)
{
    if (subjectid < 0 || subjectid >= MAX_PLAYERS || !IsPlayerConnected(subjectid)) return 0;
    new queued = 0;
    for (new receiverid = 0; receiverid < MAX_PLAYERS; receiverid++)
    {
        if (!IsPlayerConnected(receiverid)) continue;
        if (QueueCustomAnimationForPlayer(
            receiverid, subjectid, library, animation, blendDelta)) queued++;
    }
    return queued;
}

stock ClearCustomAnimationQueue(subjectid)
{
    if (subjectid < 0 || subjectid >= MAX_PLAYERS) return 0;
    new cleared = 0;
    for (new receiverid = 0; receiverid < MAX_PLAYERS; receiverid++)
    {
        if (!IsPlayerConnected(receiverid)) continue;
        if (ClearCustomAnimationQueueForPlayer(receiverid, subjectid)) cleared++;
    }
    return cleared;
}

stock SendCustomAnimationToAll(subjectid, const library[], const animation[], Float:blendDelta, bool:loop)
{
    if (!IsPlayerConnected(subjectid)) return 0;
    new sent = 0;
    for (new receiverid = 0; receiverid < MAX_PLAYERS; receiverid++)
    {
        if (!IsPlayerConnected(receiverid)) continue;
        LoadIFPAnimation(receiverid, library);
        if (PlayIFPAnimationForPlayer(receiverid, subjectid, library, animation, blendDelta, loop)) sent++;
    }
    return sent;
}

stock PlayCustomAnimation(subjectid, const library[], const animation[], Float:blendDelta = 4.1)
{
    return SendCustomAnimationToAll(subjectid, library, animation, blendDelta, false);
}

stock LoopCustomAnimation(subjectid, const library[], const animation[], Float:blendDelta = 4.1)
{
    return SendCustomAnimationToAll(subjectid, library, animation, blendDelta, true);
}

stock CancelCustomAnimation(subjectid, Float:blendDelta = 4.1)
{
    if (subjectid < 0 || subjectid >= MAX_PLAYERS) return 0;
    new sent = 0;
    for (new receiverid = 0; receiverid < MAX_PLAYERS; receiverid++)
    {
        if (IsPlayerConnected(receiverid) &&
            CancelCustomAnimationForPlayer(receiverid, subjectid, blendDelta)) sent++;
    }
    return sent;
}

stock PauseCustomAnimation(subjectid)
{
    if (subjectid < 0 || subjectid >= MAX_PLAYERS) return 0;
    new sent = 0;
    for (new receiverid = 0; receiverid < MAX_PLAYERS; receiverid++)
    {
        if (IsPlayerConnected(receiverid) &&
            PauseCustomAnimationForPlayer(receiverid, subjectid)) sent++;
    }
    return sent;
}

stock ResumeCustomAnimation(subjectid)
{
    if (subjectid < 0 || subjectid >= MAX_PLAYERS) return 0;
    new sent = 0;
    for (new receiverid = 0; receiverid < MAX_PLAYERS; receiverid++)
    {
        if (IsPlayerConnected(receiverid) &&
            ResumeCustomAnimationForPlayer(receiverid, subjectid)) sent++;
    }
    return sent;
}

stock SetCustomAnimationSpeed(subjectid, Float:speed)
{
    if (subjectid < 0 || subjectid >= MAX_PLAYERS) return 0;
    new sent = 0;
    for (new receiverid = 0; receiverid < MAX_PLAYERS; receiverid++)
    {
        if (IsPlayerConnected(receiverid) &&
            SetCustomAnimationSpeedForPlayer(receiverid, subjectid, speed)) sent++;
    }
    return sent;
}

// Install-prompt support from the component.
native bool:CustomAnimationsRequired();
native bool:IsCustomAnimationsInstallPromptEnabled();
native bool:SetCustomAnimationsInstallPromptEnabled(bool:enabled);
native GetCustomAnimationsClientProtocolVersion();

stock StopCustomAnimation(subjectid, Float:blendDelta = 4.1)
{
    if (subjectid < 0 || subjectid >= MAX_PLAYERS) return 0;
    new stopped = 0;
    for (new receiverid = 0; receiverid < MAX_PLAYERS; receiverid++)
    {
        if (IsPlayerConnected(receiverid) &&
            StopCustomAnimationForPlayer(receiverid, subjectid, blendDelta)) stopped++;
    }
    return stopped;
}

native GetCustomAnimationQueueCount(receiverid, subjectid);
