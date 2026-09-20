# frozen_string_literal: true

require "nokogiri"

module Datalog
  # A table keeps its native semantics and desktop width while its enclosing
  # region can scroll with either touch or the keyboard on a narrow screen.
  module ResponsiveContent
    module_function

    def process(document)
      return unless document.output_ext == ".html" && document.content.to_s.include?("<table")

      html = Nokogiri::HTML5.fragment(document.content)
      tables = html.css("table").to_a
      tables.reject! do |table|
        table["class"].to_s.split.include?("rouge-table") || table.ancestors(".content-table").any?
      end
      return if tables.empty?

      locale = I18n.locale_code(document.site, document.data["lang"])
      label = I18n.lookup(document.site, locale, "references.table") || "Table"
      tables.each_with_index do |table, index|
        wrapper = Nokogiri::XML::Node.new("div", html)
        wrapper["class"] = "content-table"
        wrapper["role"] = "region"
        wrapper["tabindex"] = "0"
        caption = table.at_css("caption")&.text.to_s.strip
        wrapper["aria-label"] = caption.empty? ? "#{label} #{index + 1}" : caption
        table.add_previous_sibling(wrapper)
        wrapper.add_child(table)
      end
      document.content = html.to_html
    end
  end
end

Jekyll::Hooks.register %i[pages documents], :post_convert do |document|
  Datalog::ResponsiveContent.process(document)
end
