def entry:
  index("=") as $separator
  | {key: .[:$separator], value: .[$separator + 1:]};

$ARGS.positional as $args
| ($base[0] // {}) as $settings
| ($args[:$pluginCount] | map(entry | .value |= fromjson) | from_entries) as $plugins
| ($args[$pluginCount:$pluginCount + $marketplaceCount] | map(fromjson) | add // {}) as $marketplaces
| ($args[$pluginCount + $marketplaceCount:] | map(entry) | from_entries) as $env
| {}
| if $plugins != {} then .enabledPlugins = $plugins else . end
| if $marketplaces != {} then
    .extraKnownMarketplaces = (($settings.extraKnownMarketplaces // {}) + $marketplaces)
  else . end
| if $env != {} then .env = (($settings.env // {}) + $env) else . end
