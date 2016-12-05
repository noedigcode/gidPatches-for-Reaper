-- Get value with witch action was called
is_new_value,filename,sectionID,cmdID,mode,resolution,val = reaper.get_action_context()


reaper.SetExtState('gidPatches1','curtrack',string.format('%d',val),false)

