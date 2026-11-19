#if defined _custom_vehicles_included
    #endinput
#endif
#define _custom_vehicles_included

#define CUSTOM_VEHICLE_MODEL_MIN (19000)
#define CUSTOM_VEHICLE_MODEL_MAX (19999)
#define INVALID_CUSTOM_VEHICLE_ID (-1)

native bool:AddCustomVehicleModel(
    modelid,
    template_modelid,
    const dff_path[],
    const txd_path[]
);

native bool:RemoveCustomVehicleModel(modelid);
native bool:IsCustomVehicleModelRegistered(modelid);
native GetCustomVehicleModelCount();

native CreateCustomVehicle(
    modelid,
    Float:x,
    Float:y,
    Float:z,
    Float:angle,
    color1 = 0,
    color2 = 0,
    bool:add_siren = false
);

native bool:DestroyCustomVehicle(vehicleid);
native bool:IsCustomVehicle(vehicleid);
native GetCustomVehicleModel(vehicleid);
native bool:LoadAllCustomVehicles(playerid);

// Uses SAMP/water.dat. Clients activate the downloaded file
// when GTA reads DATA\WATER.DAT at the next game launch.
native bool:SetSAMPWaterData(const path[]);
native bool:ClearSAMPWaterData();
native bool:IsSAMPWaterDataSet();

native bool:LoadCustomVehicleModel(playerid, modelid);
native bool:IsCustomVehicleModelLoaded(playerid, modelid);
native GetCustomVehicleTemplateModel(modelid);
native GetCustomVehicleCount();
native GetPlayerCustomVehicle(playerid);
