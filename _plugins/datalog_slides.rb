# frozen_string_literal: true

module Jekyll
  # Stands in for the `datalog_slides` tag when the datalog-slides plugin is not
  # enabled, so a layout that uses the tag still builds. The plugin registers the
  # real tag and sets `datalog_slides` on the pages it handles; a page that sets
  # the key by hand without the plugin gets nothing and a build warning, where it
  # used to get a "coming soon" notice showing its raw configuration.
  class DatalogSlidesTag < Liquid::Tag
    def render(context)
      page = context.registers[:page]
      return "" unless page["datalog_slides"]

      Jekyll.logger.warn("datalog-slides", "#{page['path']} sets datalog_slides, but datalog_plugins.enabled does not list datalog-slides")
      ""
    end
  end
end

Liquid::Template.register_tag("datalog_slides", Jekyll::DatalogSlidesTag)
