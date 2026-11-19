#include <open.mp>
#include <custom_animations>

stock SyncIFPAnimation(subjectid, const library[], const animation[],
                       Float:blendDelta = 4.1, bool:loop = true)
{
    if (!IsPlayerConnected(subjectid)) return 0;

    new sent = 0;
    for (new receiverid = 0; receiverid < MAX_PLAYERS; receiverid++)
    {
        if (!IsPlayerConnected(receiverid)) continue;

        LoadIFPAnimation(receiverid, library);

        if (PlayIFPAnimationForPlayer(
            receiverid, subjectid, library, animation, blendDelta, loop))
        {
            sent++;
        }
    }
    return sent;
}
