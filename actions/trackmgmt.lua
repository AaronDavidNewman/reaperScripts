
-- return the complement of a value 0-1
function complement(prop)
  return math.abs(1.0 - prop);
end

-- emulate ? : behavior that I can't live without
function ternary(condition, first, second)
  if (condition) then return first;
  else return second;
  end
end  
--[[
Return max index of selected track, 0 if none selected
--]]
function getSelectedTrack()
  trackCount = reaper.GetNumTracks();
  while trackCount > 0 do
     trackMedia = reaper.GetTrack(0, trackCount - 1);
     isSelected = reaper.GetMediaTrackInfo_Value(trackMedia, "I_SELECTED");
     if (isSelected > 0) then
        return trackCount - 1;
     end
     -- reaper.ShowConsoleMsg(string.format("arm: %f %f",trackCount , isSelected));
     trackCount = trackCount - 1;
  end
  return 0;
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
      reaper.GetSet_LoopTimeRange(true, true, startOut, endOut, true);
  end
  -- reaper.ShowConsoleMsg(string.format("loop range is %f %f\n", startOut, endOut));
end
--[[
Create a new region the same size as the current loop region, after the current loop region.
Then advance the loop range to that region.
--]]
function addNewRegionAfterLoop()
  startOut, endOut = reaper.GetSet_LoopTimeRange(false, true, 0, 0, false);
  newEnd = endOut + (endOut - startOut);
  reaper.AddProjectMarker(0, true, endOut, newEnd, '',-1);
  reaper.GetSet_LoopTimeRange(true, true, endOut, newEnd, true);
end
--[[
Copy the information from the existing loop range to the next [n] bars after the 
loop range, where [n] is the length of the existing range. 
--]]
function copyAdvanceLoopRange()
  curTrack = getSelectedTrack();
  startOut, endOut = reaper.GetSet_LoopTimeRange(false, true, 0, 0, false);
  loopLength = endOut - startOut;
  if (loopLength < 1) then
    return;
  end
  newStart = endOut;
  newEnd = startOut + endOut;
  cursorPosition = reaper.GetCursorPosition();
  trackCount = reaper.GetNumTracks();
  reaper.Main_OnCommand(40289, 0);  -- unselect all
  while trackCount > 0 do
      trackMedia = reaper.GetTrack(0, trackCount - 1);
      reaper.SetOnlyTrackSelected(trackMedia);
  
      itemCount = reaper.GetTrackNumMediaItems(trackMedia);
      while (itemCount > 0) do
        mediaItem = reaper.GetTrackMediaItem(trackMedia, itemCount - 1);
        mediaPos = reaper.GetMediaItemInfo_Value(mediaItem, "D_POSITION");
        if (mediaPos >= startOut and mediaPos <= endOut) then
          -- reaper.ShowConsoleMsg(string.format("found selection track %f pos %f\n", trackCount - 1, mediaPos));
          reaper.SetMediaItemSelected(mediaItem, 1);
          reaper.Main_OnCommand(40698, 0); -- copy
          reaper.SetEditCurPos(mediaPos + loopLength, false, false);
          reaper.Main_OnCommand(42398, 0); -- paste
          reaper.Main_OnCommand(40289, 0);  -- unselect all
        end
        itemCount = itemCount - 1;
      end
      trackCount = trackCount - 1;
   end
    reaper.SetEditCurPos(cursorPosition, false, false);
    reaper.Main_OnCommand(40289, 0);
  trackMedia = reaper.GetTrack(0, curTrack);
  reaper.SetOnlyTrackSelected(trackMedia);
end

--[[
  Find midi items in the current loop range, double the playback speed.  
  Also copy the item and paste it to midpoint of loop region since it will be slower.
--]]
function doubleMidiItemSpeed()
  reaper.Main_OnCommand(40289, 0);  -- unselect all
  curTrack = getSelectedTrack();
  startOut, endOut = reaper.GetSet_LoopTimeRange(false, true, 0, 0, false);
  loopLength = endOut - startOut;
  if (loopLength < 1) then
    return;
  end
  -- the midpoint of the loop region, since new media will be shorter
  nPos = (loopLength / 2);
  tempo = reaper.Master_GetTempo();
  -- this should be 0 if loop regions start on measure boundaries.  I set mine
  -- 1/8 note before measure starts
  tempoOffset = 30 / tempo;  -- (2 * tempo)/60 seconds
  cursorPosition = reaper.GetCursorPosition();
  trackMedia = reaper.GetTrack(0, curTrack);
  reaper.SetOnlyTrackSelected(trackMedia);

  itemCount = reaper.GetTrackNumMediaItems(trackMedia);
  while (itemCount > 0) do
    mediaItem = reaper.GetTrackMediaItem(trackMedia, itemCount - 1);
    mediaPos = reaper.GetMediaItemInfo_Value(mediaItem, "D_POSITION");
    mediaLen = reaper.GetMediaItemInfo_Value(mediaItem, "D_LENGTH");
    if (mediaPos >= startOut and mediaPos <= endOut) then
      takeCount = reaper.GetMediaItemNumTakes(mediaItem);
      if (takeCount > 0) then
        -- reaper.ShowConsoleMsg(string.format("found selection track/item/take %f %f %f\n", curTrack, itemCount, takeCount));
        take = reaper.GetMediaItemTake(mediaItem, takeCount - 1); -- we assume the last take is the one you want.
        reaper.SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", 2);  -- double midi tempo
        reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", -1 * tempoOffset);  -- double midi tempo
        reaper.SetMediaItemInfo_Value(mediaItem, "D_LENGTH", mediaLen / 2);  -- truncate media item to 1/2 length
        reaper.SetMediaItemSelected(mediaItem, 1); -- copy item
        reaper.Main_OnCommand(40698, 0); -- copy
        reaper.SetEditCurPos(mediaPos + nPos, false, false);  -- set the cursor position to 1/2 way through loop
        reaper.Main_OnCommand(42398, 0); -- paste to new position
        reaper.Main_OnCommand(40289, 0);  -- unselect all
      end
    end
    itemCount = itemCount - 1;
    reaper.SetEditCurPos(cursorPosition, false, false);
    reaper.Main_OnCommand(40289, 0);
  end
  trackMedia = reaper.GetTrack(0, curTrack);
  reaper.SetOnlyTrackSelected(trackMedia);
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
Delete media items on this track, starting from the current loop range.
--]]
function deleteFutureItemsOnTrack()
   startOut, endOut = reaper.GetSet_LoopTimeRange(false, true, 0, 0, false);
  -- reaper.ShowConsoleMsg(string.format("start pos %f", startOut));
  trackCount = reaper.GetNumTracks();
  while trackCount > 0 do
     trackMedia = reaper.GetTrack(0, trackCount - 1);
     
     isSelected = reaper.GetMediaTrackInfo_Value(trackMedia, "I_SELECTED");
     if (isSelected > 0) then
     itemCount = reaper.GetTrackNumMediaItems(trackMedia);
     while (itemCount > 0) do
       mediaItem = reaper.GetTrackMediaItem(trackMedia, itemCount - 1);
       mediaPos = reaper.GetMediaItemInfo_Value(mediaItem, "D_POSITION");
       -- reaper.ShowConsoleMsg(string.format("media pos %f", mediaPos));
       if (mediaPos >= startOut) then
         reaper.DeleteTrackMediaItem(trackMedia, mediaItem);
       end
       itemCount = itemCount - 1
      end
     end
     trackCount = trackCount - 1;
  end
end

--[[
Mute drum tracks.  If > number of tracks, mute all.
--]]
function muteDisarm()
  trackCount = reaper.GetNumTracks();
  while trackCount > 0 do
     trackMedia = reaper.GetTrack(0, trackCount - 1);
     
     isSelected = reaper.GetMediaTrackInfo_Value(trackMedia, "I_SELECTED");
     if (isSelected > 0) then
        reaper.SetMediaTrackInfo_Value(trackMedia, "I_RECARM", 0);
        reaper.SetMediaTrackInfo_Value(trackMedia, "B_MUTE", 1);
     end
     -- reaper.ShowConsoleMsg(string.format("arm: %f %f",trackCount , isSelected));
     trackCount = trackCount - 1;
  end

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
  loopCount = loopCount + 1;
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
  toUpdate = math.random(100);
  if (toUpdate > 95) then
    initGfx();
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
buttons[0] = {w=80, h=40, x = 50, y = 50, text="CopyLoop", r=0.2, g = 0.8, b=0.3, handler = copyAdvanceLoopRange };
buttons[1] = {w=80, h=40, x = 150, y = 50, text="Adv Loop", r=0.1, g = 0.2, b=1, handler = advanceLoopRange };
buttons[2] = {w=80, h=40, x = 250, y = 50, text="Midi x2", r=0.1, g = 0.2, b=1, handler = doubleMidiItemSpeed };
buttons[3] = {w=80, h=40, x = 50, y = 110, text="Arm Sel", r=1, g = 0.2, b=0.3, handler = armSelected };
buttons[4] = {w=80, h=40, x = 250, y = 110, text="Disarm", r=0.6, g = 0.1, b=0.1, handler = disarmAll };
buttons[5] = {w=80, h=40, x = 50, y = 170, text="DelMed", r=0.6, g = 0.4, b=0.1, handler = deleteFutureItemsOnTrack };
buttons[6] = {w=80, h=40, x = 150, y = 170, text="AddRgn", r=0.6, g = 0.4, b=0.1, handler = addNewRegionAfterLoop };
buttons[7] = {w=80, h=40, x = 50, y = 220, text="Quit", r=1, g = 0, b=0.3, handler = nil };

maxButtonIndex = 7;
loopCount = 0;
-- debounce mouse to avoid double-click
debounceCount = 0;
debounceTime = 20;

-- render ugly buttons
initGfx();

-- start event loop
reaper.defer(monitorInput);
