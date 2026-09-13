# frozen_string_literal: true

module Jekyll
  # Stands in for the `datalog_comments` tag when the datalog-comments plugin is
  # not enabled, so a layout that uses the tag still builds. The plugin registers
  # the real tag and sets `datalog_comments` on the pages it handles; a page that
  # sets the key by hand without the plugin gets nothing and a build warning,
  # where it used to get a "coming soon" notice.
  class DatalogCommentsTag < Liquid::Tag
    def render(context)
      page = context.registers[:page]
      return "" unless page["datalog_comments"]

      Jekyll.logger.warn("datalog-comments", "#{page['path']} sets datalog_comments, but datalog_plugins.enabled does not list datalog-comments")
      ""
    end
  end
end

Liquid::Template.register_tag("datalog_comments", Jekyll::DatalogCommentsTag)
