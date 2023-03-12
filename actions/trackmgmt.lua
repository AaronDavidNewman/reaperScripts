
-- return the complement of a value 0-1
function complement(prop)
  return math.abs(1.0 - prop);
end

-- emunlate ? : behavior that I can't live without
function ternary(condition, first, second)
  if (condition) then return first;
  else return second;
  end
end  

--[[
Mute drum tracks.  If > number of tracks, mute all.
--]]
function muteDrumTracks(track)
  tracknum = 0
  while tracknum < 3 do
    trackMedia = reaper.GetTrack(0, tracknum);
    if (tracknum == track) then
      reaper.SetMediaTrackInfo_Value(trackMedia, "B_MUTE", 0);
    else 
      reaper.SetMediaTrackInfo_Value(trackMedia , "B_MUTE", 1);
    end
    tracknum = tracknum + 1
  end
end

--[[
Disable the sequencer.  This is desireable if there is midi
on the drum tracks, and we want the recorded drum track
--]]
function enableSequencer(enable)
  tracknum = 0
  while tracknum < 3 do
    trackMedia = reaper.GetTrack(0, tracknum);
    reaper.TrackFX_SetEnabled(trackMedia, 0, enable);
    tracknum = tracknum + 1
  end
end

--[[
Get input from a menu to mute/unmute drum tracks
--]]
function getMuteInput()
  menuval = gfx.showmenu("Play Track 1|Play Track 2|Play Track 3|Mute All|Close");
  if (menuval < 5) then
    muteDrumTracks(menuval - 1);
    advanceLoopRange();
  end
end

--[[
Disarm all tracks
--]]
function disarmAll()
  trackCount = reaper.GetNumTracks();
  while trackCount > 0 do
     trackMedia = reaper.GetTrack(0, trackCount - 1);
     reaper.SetMediaTrackInfo_Value(trackMedia, "I_RECARM", 0);
     trackCount = trackCount - 1;
  end
end

--[[
Arm and unmute selected tracks
--]]
function armSelected()
  trackCount = reaper.GetNumTracks();
  while trackCount > 0 do
     trackMedia = reaper.GetTrack(0, trackCount - 1);
     
     isSelected = reaper.GetMediaTrackInfo_Value(trackMedia, "I_SELECTED");
     if (isSelected > 0) then
        reaper.SetMediaTrackInfo_Value(trackMedia, "I_RECARM", 1);
        reaper.SetMediaTrackInfo_Value(trackMedia, "B_MUTE", 0);
     end
     -- reaper.ShowConsoleMsg(string.format("arm: %f %f",trackCount , isSelected));
     trackCount = trackCount - 1;
  end
end

--[[
Wherever the loop region is set up, advance it to the next part
--]]
function advanceLoopRange()
  startOut, endOut = reaper.GetSet_LoopTimeRange(false, true, 0, 0, false);
  if (endOut > startOut) then
      length = endOut - startOut;
      startOut = startOut + length;
      endOut = endOut + length;
      reaper.GetSet_LoopTimeRange(true, true, startOut, endOut, false);
  end
  -- reaper.ShowConsoleMsg(string.format("loop range is %f %f\n", startOut, endOut));
end

--[[
Get input for the sequencer enable/disable
--]]
function getFxInput()
  menuval = gfx.showmenu("Enable Sequencers|Disable Sequencers|Close");
  if (menuval < 3) then
    enableSequencer(ternary(menuval == 1, 1, 0));
  end
end

--[[
Return true if there has been a click in button region
--]]
function checkClick(rect)
  mousex = gfx.mouse_x;
  mousey = gfx.mouse_y;
  if (mousex > rect.x and mousex < rect.w + rect.x and mousey > rect.y and mousey < rect.h + rect.y
    and (gfx.mouse_cap & 1 > 0)) then
    return true;
  end
  return false;
end

--[[
create the ugly reaper buttons
--]]
function drawButton(btn)
  gfx.r = btn.r;
  gfx.g = btn.g;
  gfx.b = btn.b;
  gfx.rect(btn.x , btn.y , btn.w, btn.h, 1);
  texty = btn.y + (btn.h / 2);
  gfx.x = btn.x + 10;
  gfx.y = texty;
  gfx.r = complement(btn.r);
  gfx.g = complement(btn.g);
  gfx.b = complement(btn.b);
  gfx.drawstr(btn.text);
  -- reaper.ShowConsoleMsg(string.format("%f %f %f  %f %f",btn.x , btn.y , btn.w, btn.h, texty));
end

--[[
Main logic loop.  Monitor the button regions and perform the action.
If the quit button isn't clicked, do it again.
--]]
function monitorInput()
  mousex = gfx.mouse_x;
  mousey = gfx.mouse_y;
  if (debounceCount > 0) then
    debounceCount = debounceCount - 1;
    reaper.defer(monitorInput);
    return;
  end;
  bix = 0;
  while (bix <= maxButtonIndex) do
    if (checkClick(buttons[bix])) then
       if (buttons[bix].handler == nil) then
          gfx.quit();
          return;
        end;
        buttons[bix].handler();
        debounceCount = 10;
    end;
    bix = bix + 1;
  end
  reaper.defer(monitorInput);
end

function initGfx()
  bix = 0;
  gfx.init("Loop Tracks", 350, 270, false);
  while (bix <= maxButtonIndex) do
      drawButton(buttons[bix]);
      bix = bix + 1;
  end
  gfx.update();
end

-- create ugly buttons
buttons = {};
buttons[0] = {w=80, h=40, x = 50, y = 50, text="Mute", r=1, g = 0.2, b=0.3, handler = getMuteInput };
buttons[1] = {w=80, h=40, x = 150, y = 50, text="Seq", r=0.1, g = 1, b=0.3, handler = getFxInput };
buttons[2] = {w=80, h=40, x = 250, y = 50, text="Adv Loop", r=0.1, g = 0.2, b=1, handler = advanceLoopRange };
buttons[3] = {w=80, h=40, x = 50, y = 110, text="Arm Sel", r=1, g = 0.2, b=0.3, handler = armSelected };
buttons[4] = {w=80, h=40, x = 150, y = 110, text="Disarm", r=0.6, g = 0.1, b=0.1, handler = disarmAll };
buttons[5] = {w=80, h=40, x = 50, y = 220, text="Quit", r=1, g = 0, b=0.3, handler = nil };

maxButtonIndex = 5;
-- debounce mouse to avoid double-click
debounceCount = 0;
debounceTime = 20;

-- render ugly buttons
initGfx();

-- start event loop
reaper.defer(monitorInput);

