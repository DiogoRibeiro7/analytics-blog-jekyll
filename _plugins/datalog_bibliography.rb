# frozen_string_literal: true

module Jekyll
  class DatalogBibliographyTag < Liquid::Tag
    def render(context)
      page = context.registers[:page]
      bib_data = page["datalog_bibliography"]
      return "" unless bib_data

      <<~HTML
        <div class="datalog-bibliography-placeholder">
          <p>Bibliography feature coming soon.</p>
        </div>
      HTML
    end
  end
end

Liquid::Template.register_tag("datalog_bibliography", Jekyll::DatalogBibliographyTag)
