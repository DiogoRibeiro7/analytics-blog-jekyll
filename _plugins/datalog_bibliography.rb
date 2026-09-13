# frozen_string_literal: true

module Jekyll
  # Stands in for the `datalog_bibliography` tag when the datalog-citations
  # plugin is not enabled, so a layout that uses the tag still builds. The plugin
  # registers the real tag and sets `datalog_bibliography` on the pages it
  # handles; a page that sets the key by hand without the plugin gets nothing and
  # a build warning, where it used to get a "coming soon" notice.
  class DatalogBibliographyTag < Liquid::Tag
    def render(context)
      page = context.registers[:page]
      return "" unless page["datalog_bibliography"]

      Jekyll.logger.warn("datalog-citations", "#{page['path']} sets datalog_bibliography, but datalog_plugins.enabled does not list datalog-citations")
      ""
    end
  end
end

Liquid::Template.register_tag("datalog_bibliography", Jekyll::DatalogBibliographyTag)
