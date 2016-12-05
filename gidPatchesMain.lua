section = 'gidPatches1'
key_curTrack = 'curtrack'
key_numTracksShown = 'numTracksShown'

instTracks = {}
ninst = 0
hiddenTracks = {}
nhidden = 0
distTrack = -1

local function help()
  reaper.ShowConsoleMsg([[ 
  
  ----------------------------------------
  gidPatches
  
  - Create a track named "_Distribute Midi".
  - Make sure the track receives all the MIDI input that you require, either
    via sends or by monitoring MIDI input.
  - Also ensure the track receives Virtual Keyboard input.
  - Insert the "GVDK MIDI Patches" effect in the track.
  - Also add the "MIDItoReaControlPath" effect.
  - Name all tracks that you want to be hidden with a leading underscore,
    e.g. "_Effects".
  - Name all instrument tracks withOUT a leading underscore, e.g. "Piano".
  - Run the "gidPatchesMain.lua" script to show your instruments. The script
    will automatically delete all the sends of the "_Distribute Midi" track
    and recreate them, pointing to all your instrument tracks. Each send
    uses a different MIDI channel, in order of the tracks. Hidden tracks are
    ignored.
  - Open the Reaper Action List, find the "gidPatchesChange.lua" script, add
    a action shortcut. Now, send a program change message to the
    "_Distribute Midi" track. The "GVDK MIDI Patches" effect will translate
    this into a MIDI CC message which is sent to the Reaper control path by
    the "MIDItoReaControlPath" effect and should be seen in the shortcut
    editor. Save this shortcut.
  - Now, by sending program change messages, the currently selected track in
    the GUI should change. The MIDI is also only sent to the appropriate track
    thanks to the automatic setup of the track sends.
  - Press F5 to refresh the track list.
  - Press d to see some debug messages.
  - Press Space for all notes off.
  - Use 1-9 to change programs. This is why the connection of the virtual
    keyboard is important, as the script uses the virtual keyboard to send
    MIDI messages to the "_Distribute Midi" track.
  ]])
end

-----------------------------------------------------------------------------
-- Convert a hex color to integers r,g,b
local function hex2rgb(num)
  
  if string.sub(num, 1, 2) == "0x" then
    num = string.sub(num, 3)
  end

  local red = string.sub(num, 1, 2)
  local blue = string.sub(num, 3, 4)
  local green = string.sub(num, 5, 6)
  
  red = tonumber(red, 16)
  blue = tonumber(blue, 16)
  green = tonumber(green, 16)
  
  return red, green, blue
  
end
-----------------------------------------------------------------------------
-- Take discrete RGB values and return the combined integer
-- (equal to hex colors of the form 0xRRGGBB)
local function rgb2num(red, green, blue)
  
  green = green * 256
  blue = blue * 256 * 256
  
  return red + green + blue

end
-----------------------------------------------------------------------------
-- Improved roundrect() function with fill, adapted from mwe's EEL example.
local function roundrect(x, y, w, h, r, antialias, fill)
  
  local aa = antialias or 1
  fill = fill or 0
  
  if fill == 0 or false then
    gfx.roundrect(x, y, w, h, r, aa)
  elseif h >= 2 * r then
    
    -- Corners
    gfx.circle(x + r, y + r, r, 1, aa)    -- top-left
    gfx.circle(x + w - r, y + r, r, 1, aa)    -- top-right
    gfx.circle(x + w - r, y + h - r, r , 1, aa)  -- bottom-right
    gfx.circle(x + r, y + h - r, r, 1, aa)    -- bottom-left
    
    -- Ends
    gfx.rect(x, y + r, r, h - r * 2)
    gfx.rect(x + w - r, y + r, r + 1, h - r * 2)
      
    -- Body + sides
    gfx.rect(x + r, y, w - r * 2, h + 1)
    
  else
  
    r = h / 2 - 1
  
    -- Ends
    gfx.circle(x + r, y + r, r, 1, aa)
    gfx.circle(x + w - r, y + r, r, 1, aa)
    
    -- Body
    gfx.rect(x + r, y, w - r * 2, h)
    
  end  
  
end
-----------------------------------------------------------------------------
-- Get track name. n starts at 1.
local function getTrackName(n)
  track = reaper.GetTrack(0,n-1)
  retval, track_name = reaper.GetSetMediaTrackInfo_String(track,'P_NAME','',false)
  return track_name
end
-----------------------------------------------------------------------------
local function refreshTracks()
  -- Fill tracks array with names of instrument tracks
  tracks = {}
  for i=1,ninst do
    tracks[i] = string.format("%d. %s",i,getTrackName(instTracks[i]))
  end
end
-----------------------------------------------------------------------------
local function message(msg)
  msg_text = msg
  msg_count = msg_max
end
local function display_message()
  if (msg_count>0) then
    gfx.x,gfx.y = 0,0
    gfx.set(1,0.5,0.5,1)
    gfx.setfont(1,'Arial',16)
    gfx.printf(msg_text)
    msg_count = msg_count - 1
  end
end
-----------------------------------------------------------------------------
local function log(msg)
  -- (un)comment to dis/enable info messages
  --reaper.ShowConsoleMsg(msg)
end
local function error(msg)
  reaper.ShowConsoleMsg(msg)
end
-----------------------------------------------------------------------------
local function updateTrackSends()
  distTrackName = '_Distribute Midi'
  instTracks = {}
  ninst = 0
  hiddenTracks = {}
  nhidden = 0
  distTrack = -1
  numtracks = reaper.CountTracks(0)
  
  -- Identify tracks
  for i=1,numtracks,1 do
    name = getTrackName(i)
    if name == distTrackName then
      distTrack = i
    elseif name:sub(1,1) == '_' then
      hiddenTracks[nhidden+1] = i
      nhidden = nhidden + 1
    else
      instTracks[ninst+1] = i
      ninst = ninst + 1
    end
  end
  
  -- Do some sanity checking
  if distTrack < 0 then
    error('\n--------------------------\n')
    error( string.format('Create a track named "%s"\n', distTrackName) )
    error('--------------------------\n')
    return
  end
  
  -- Print track info to console
  log('\n--------------------------\n')
  log('Instrument tracks:\n')
  for i=1,ninst do
    log(string.format('   %d. %s\n',instTracks[i],getTrackName(instTracks[i])))
  end  
  log('Hidden tracks:\n')
  for i=1,nhidden do
    log( string.format('   %d. %s\n',hiddenTracks[i],getTrackName(hiddenTracks[i])) )
  end
  log( string.format('Distribute track: %d\n', distTrack) )
  
  -- Remove all sends on distribute track
  tr_dist = reaper.GetTrack(0,distTrack-1)
  numsends = reaper.GetTrackNumSends(tr_dist,0)
  while numsends>0 do
    reaper.RemoveTrackSend(tr_dist,0,0)
    numsends = numsends - 1
  end
  
  -- Add sends to instrument tracks and set midi channels
  for i=1,ninst do
    tr_temp = reaper.GetTrack(0,instTracks[i]-1)
    reaper.CreateTrackSend(tr_dist,tr_temp)
    reaper.SetTrackSendInfo_Value(tr_dist,0,i-1,'I_MIDIFLAGS',33+i-1)
    -- low 5 bits: i, high 5 bits: 1
  end
  
end -- end function
-----------------------------------------------------------------------------
local function Main()
  if (reaper.HasExtState(section,key_curTrack)) then
    curtrack = tonumber( reaper.GetExtState(section, key_curTrack ) )
  end

  local char = gfx.getchar()
  if (showchars) then
    if char>0 then
      message(string.format('<char: %d>',char))
    end
  end
  -- 27 is escape keyboard button
  -- -1 means window has been closed
  if char ~= 27 and char ~= -1 then
    reaper.defer(Main)
  end
  -- Close window if escape is pressed
  if char == 27 then
    gfx.quit()
  end
  -- Debug mode; Show or hide keyboard character
  -- 100 = d
  if (char==100) then
    if (showchars) then
      showchars = false
      message('Debug mode off')
    else
      showchars = true
      message('Debug mode on')
    end
  end
  
  -- Show help message when 'h' is pressed.
  if (char==104) then
    help()
  end
  
  -- Space bar sends all notes off, sustain zero and pitch bend zero to vkbd
  if (char==32) then
    message('Space bar pressed.')
  end
  display_message()
  -- Keys 1 (ascii 49) to 9 send prog changes over virtual keyboard
  if (char >= 49) and (char <= 57) then
    reaper.StuffMIDIMessage(0,0xC0,char-49,0)
  end
  -- Run Init() again if F5 is pressed
  if char == 26165 then
    updateTrackSends()
    refreshTracks()
    message('<refreshed>')
  end
    
  gfx.clear = rgb2num(64,64,64) -- Background
  
  gfx.set(1, 0.5, 0.5, 1)
  gfx.setfont(1,'Arial',18)
  local spacing=gfx.measurestr('Arial')
  gfx.x,gfx.y = 20,20
  for i=1,ninst,1 do
    local x, y = gfx.x, gfx.y
    if (i==curtrack) then
      gfx.set(1, 0.5, 0.5, 1)
      local str_w, str_h = gfx.measurestr(tracks[i])
      gfx.rect(x-(str_h/4),y-(str_h/4),str_w+str_h/2, str_h + str_h/2,10,1,1)
      gfx.set(0.25,0.25,0.25,1)
    else
      gfx.set(1,0.5,0.5,1)
    end
    gfx.drawstr(tracks[i])
    gfx.y = y + spacing
    gfx.x = x
  end
  
  gfx.update()

end
-----------------------------------------------------------------------------
local function WaitThenMain()
  if (wait>0) then
    wait = wait - 1
    reaper.defer(WaitThenMain)
  else
    Main()
  end
end
-----------------------------------------------------------------------------
-- Initialise
showchars=false
msg_max = 64 -- The number of cycles that a message will be displayed
msg_text = ''
msg_count = 0
curtrack = 1
updateTrackSends()
refreshTracks()
local w,h = 240,600
gfx.init("Patches", w, h, 0, 1366-w-10, (768-h)/2)
gfx.printf('\nHello and welcome.\n\nPress h for help.')
wait=64
WaitThenMain()


