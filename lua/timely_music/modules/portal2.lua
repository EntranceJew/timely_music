AddCSLuaFile()
if !IsMounted("portal2") then return end

local portal2ambient = TimelyMusic.MusicThemeInterface:new({
  songs = {
    ["00"] = "sound/music/sp_a3_transition01_b1.wav",
    ["01"] = "sound/music/sp_a1_intro3_b1.wav",
    ["02"] = "sound/music/sp_a2_bts3_b1.wav",
    ["03"] = "sound/music/sp_a4_intro_b2.wav",
    ["04"] = "sound/music/sp_a3_jump_intro_b1.wav",
    ["05"] = "sound/music/sp_a2_bts5_x1.wav",
    ["06"] = "sound/music/sp_a3_01_b2.wav",
    ["07"] = "sound/music/mainmenu/portal2_background05.wav",
    ["08"] = "sound/music/sp_a1_intro6.wav",
    ["09"] = "sound/music/sp_a2_bts5_b0.wav",
    ["10"] = "sound/music/sp_factory_01_redemption_01.wav",
    ["11"] = "sound/music/sp_a2_pull_the_rug_r1.wav",
    ["12"] = "sound/music/sp_a1_wakeup_b1.wav",
    ["13"] = "sound/music/sp_a3_03_b1.wav",
    ["14"] = "sound/music/mainmenu/portal2_background03.wav",
    ["15"] = "sound/music/sp_a4_tb_trust_drop_b1.wav",
    ["16"] = "sound/music/sp_a1_wakeup_b2.wav",
    ["17"] = "sound/music/sp_under_potatos_x1_01.wav",
    ["18"] = "sound/music/sp_a2_turret_intro_b1.wav",
    ["19"] = "sound/music/sp_a2_bts3_b1.wav",
    ["20"] = "sound/music/sp_intro_01_08_chamberexit.wav",
    ["21"] = "sound/music/sp_a4_tb_intro_b1.wav",
    ["22"] = "sound/music/sp_a4_intro_b3.wav",
    ["23"] = "sound/music/sp_a4_intro_b2.wav",
  }
})
function portal2ambient:GetMusicForCondition(event_name, event_data)
  if !event_data.in_combat then
    return self.songs[event_data.time_hours_str]
  end
end
TimelyMusic.AddTheme("portal2ambient", portal2ambient)

local portal2active = TimelyMusic.MusicThemeInterface:new({
  songs = {
    ["00"] = "sound/music/sp_a3_portal_intro_b1.wav",
    ["01"] = "sound/music/sp_a2_core_b3p4.wav",
    ["02"] = "sound/music/portal2_robots_ftw.wav", --  perfect
    ["03"] = "sound/music/sp_a3_01_b4.wav",
    ["04"] = "sound/music/sp_a2_bts1_b1.wav",
    ["05"] = "sound/music/sp_a4_finale1_b1.wav",
    ["06"] = "sound/ambient/music/looping_radio_mix.wav",
    ["07"] = "sound/music/sp_a4_finale4_b2.wav",
    ["08"] = "sound/music/sp_a3_jump_intro_b2.wav",
    ["09"] = "sound/music/sp_a3_speed_ramp_b2.wav",
    ["10"] = "sound/music/sp_a4_finale3_b4.wav",
    ["11"] = "sound/music/sp_a2_core_b8p2.wav",
    ["12"] = "sound/music/mainmenu/portal2_background01.wav",
    ["13"] = "sound/music/sp_a2_bts5_x1.wav",
    ["14"] = "sound/music/sp_a4_tb_wall_button_b1.wav",
    ["15"] = "sound/music/sp_a4_finale1_b1p2.wav",
    ["16"] = "sound/music/mainmenu/portal2_background04.wav",
    ["17"] = "sound/music/sp_a2_catapult_intro.wav",
    ["18"] = "sound/music/sp_a3_bomb_flings_b1.wav",
    ["19"] = "sound/music/sp_a3_speed_ramp_b1.wav",
    ["20"] = "sound/music/mainmenu/portal2_background02.wav",
    ["21"] = "sound/music/sp_a4_tb_catch_b1a.wav",
    ["22"] = "sound/music/sp_a3_01_b3.wav",
    ["23"] = "sound/music/sp_a3_portal_intro_b4_2.wav",
  }
})
function portal2active:GetMusicForCondition(event_name, event_data)
  if !event_data.in_combat then
    return self.songs[event_data.time_hours_str]
  end
end
TimelyMusic.AddTheme("portal2active", portal2active)