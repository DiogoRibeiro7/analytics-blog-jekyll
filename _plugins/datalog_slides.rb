# frozen_string_literal: true

module Jekyll
  class DatalogSlidesTag < Liquid::Tag
    def render(context)
      page = context.registers[:page]
      slides_data = page["datalog_slides"]
      return "" unless slides_data

      # Render a simple placeholder or embed
      <<~HTML
        <div class="datalog-slides-placeholder">
          <p>Slides feature coming soon. Configured: #{slides_data}</p>
        </div>
      HTML
    end
  end
end

Liquid::Template.register_tag("datalog_slides", Jekyll::DatalogSlidesTag)
