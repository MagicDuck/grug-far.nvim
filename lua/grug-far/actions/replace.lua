local function replace(buf, context)
  P('sttufff----------')
  -- TODO (sbadragan): just a test of writing a file, it worked
  -- The idea is to process files with rg --passthrough -N <search> -r <replace> <filepath>
  -- then get the output and write it out to the file using libuv
  -- local f = io.open(
  --   './reactUi/src/pages/IncidentManagement/IncidentDetails/components/PanelDisplayComponents/useIncidentPanelToggle.js',
  --   'w+')
  -- if f then
  --   f:write("stuff")
  --   f:close()
  -- end
end

return replace
