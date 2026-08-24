# Plugin development guide

The DataLog theme ships with a lightweight plugin system so you can layer custom behaviour on top of the bundled layouts without monkey patching the theme. This guide covers the available hooks, how to register plugins, and best practices for packaging extensions for the community marketplace.

## Architecture overview

* `_plugins/plugin_loader.rb` instantiates enabled plugins during the Jekyll build, registers any Liquid tags they expose, and wires up lifecycle hooks via `Jekyll::Hooks`.
* `lib/datalog/plugin_system.rb` defines the base `Datalog::PluginSystem::Plugin` class that plugins inherit from. The module also keeps track of the active plugin instances so Liquid tags can access runtime state.
* Plugins live under `lib/datalog/plugins/` and are required automatically when the loader boots.

Enable plugins in your `_config.yml` using the `datalog_plugins` key. Plugins can declare dependencies on one another and will be loaded using a dependency-aware resolver:

```yaml
datalog_plugins:
  enabled:
    - datalog-search # core indexing features
    - datalog-citations
    - datalog-comments
  options:
    datalog-comments:
      provider: giscus
      repo: owner/repo
      mapping: pathname
```

Each entry in `enabled` must match the plugin identifier returned by `MyPlugin.id`. Configuration values are passed to the plugin constructor and made available via the `config` accessor.

### Declaring dependencies and priorities

The base class exposes two helpers so plugins can express ordering requirements:

```ruby
class Citations < Datalog::PluginSystem::Plugin
  id "datalog-citations"
  depends_on "datalog-search"   # ensure the search index is ready
  priority :high                 # run before lower priority plugins
end
```

* `depends_on(*ids)` accepts one or more plugin identifiers. The loader will raise a `PluginDependencyError` if any dependency is missing or if a cycle is detected. The error message lists the dependency chain, available plugins, and a remediation hint (for example: `Cannot load 'datalog-citations'` followed by the missing plugin).
* `priority` replaces Jekyll's generator priority. Accepted values are `:highest`, `:high`, `:normal`, `:low`, and `:lowest`. When multiple plugins are eligible to load, higher priority plugins win the tie-break. Dependencies always take precedence over priority.

To inspect the resolved graph, run `ruby scripts/visualize_plugins.rb` to output a GraphViz DOT diagram summarizing load order and edges. This is helpful when integrating new plugins into larger stacks.

## Hook reference

Plugins can implement any of the following methods. All hooks are optional.

| Hook | When it runs | Typical use cases |
| --- | --- | --- |
| `before_render(document, payload)` | Right before a document is rendered. | Derive computed front matter, normalize metadata, inject helper variables for templates. |
| `after_post_process(document)` | After a document is written to disk. | Copy auxiliary assets, emit logs, or trigger external services. |
| `custom_liquid_tags` | During plugin boot. Return a hash of `{ "tag_name" => Liquid::TagSubclass }`. | Expose custom Liquid tags or blocks so layouts can call into your plugin. |
| `search_indexing(document)` | After a document is rendered. Must return a hash. | Append structured metadata that will be merged into `doc.datalog_search_extensions` for use in `search.json`. |

The loader automatically catches and logs exceptions raised inside hooks so a failing plugin will not crash the entire build.

## Creating a plugin

1. Create a new file under `lib/datalog/plugins/`. Inherit from `Datalog::PluginSystem::Plugin` and set a stable identifier:

   ```ruby
   module Datalog
     module Plugins
       class Glossary < Datalog::PluginSystem::Plugin
         id "datalog-glossary"

         def before_render(document, _payload)
           terms = Array(document.data["glossary"])
           document.data["datalog_glossary"] = terms
         end

         class GlossaryTag < Liquid::Tag
           def render(context)
             plugin = Datalog::PluginSystem.plugin("datalog-glossary")
             return "" unless plugin

             plugin.render_glossary(context)
           end
         end

         def custom_liquid_tags
           { "datalog_glossary" => GlossaryTag }
         end
       end
     end
   end
   ```

2. Update `_config.yml` to enable the plugin (and optionally supply configuration).
3. If you expose Liquid tags, document how to use them in your README or docs page.

## Testing tips

* Add automated checks under `tests/` that read the built site via `SiteBuilder.json` or `SiteBuilder.read`. This ensures your plugin interacts correctly with the generated output.
* Run `bundle exec ruby -Itests -e "Dir['tests/test_*.rb'].sort.each { |file| require_relative file }"` locally before submitting a pull request.

## Sharing plugins

To list a community plugin in the marketplace:

1. Fork the repository and add an entry to `docs/site/_data/plugins.yml` with the plugin name, summary, hook usage, and configuration keys.
2. Add usage notes, screenshots, or demo links to `docs/site/plugins/index.md` if needed.
3. Open a pull request that includes a link to the plugin repository and basic installation instructions.

If you are building a private extension, you can still use the same directory structure—just keep the file under `_plugins/` in your downstream site and the loader will pick it up when the identifier matches.
