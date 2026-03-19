# frozen_string_literal: true

module Jekyll
  class DatalogCommentsTag < Liquid::Tag
    def render(context)
      page = context.registers[:page]
      return "" unless page["datalog_comments"]

      <<~HTML
        <div class="datalog-comments-placeholder">
          <p>Comments feature coming soon.</p>
        </div>
      HTML
    end
  end
end

Liquid::Template.register_tag("datalog_comments", Jekyll::DatalogCommentsTag)
