-- TODO (sbadragan): might need to disable some flags, like:
-- --no-include-zero --no-byte-offset
-- --hyperlink-format=none
-- --max-columns=0
-- --no-max-columns-preview --no-trim
-- blacklist: --help --quiet
-- Hmmm, there are just too many things that could completely screw it up ... I think we need a whitelist of useful
-- flags that we allow the user to pass, otherwise replacing would not work
return {
  '--pre',
  '--pre-glob',
  '--search-zip', '-z',

  '--help'
}
