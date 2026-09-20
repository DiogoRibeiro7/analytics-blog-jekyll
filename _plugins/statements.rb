# frozen_string_literal: true

require "cgi"

module Datalog
  # Theorems, lemmas and the other statements of mathematical writing, and
  # proofs. Articles marked them with a blockquote and a bold "Theorem 1.",
  # typed by hand:
  #
  #   {% theorem id="thm-consistency" title="Consistency" %}
  #   Let $\hat\theta_n$ be ...
  #   {% endtheorem %}
  #
  #   {% proof for="thm-consistency" %}
  #   ...
  #   {% endproof %}
  #
  # Statements are numbered with figures and tables (_plugins/references.rb):
  # each kind counts on its own, {% ref thm-consistency %} reads "Theorem 1",
  # and a duplicate id stops the build. `label="A"` names a statement
  # "Theorem A" instead of numbering it. A proof is not numbered; with `for`
  # its heading reads "Proof of Theorem 1".
  class StatementTag < Liquid::Block
    def initialize(tag_name, markup, options)
      super
      @kind = tag_name
      @markup = markup
    end

    def render(context)
      attributes = References.attributes(@markup, context, @kind)
      id = References.validate_id(attributes["id"], @kind)
      custom = attributes["label"]
      References.validate_label(custom, @kind)
      body = References.markdown(context, super)

      number = custom ? %( data-ref-number="#{CGI.escapeHTML(custom)}") : ""
      title = attributes["title"].to_s.strip
      title = title.empty? ? "" : %( <span class="datalog-statement__title">(#{CGI.escapeHTML(title)})</span>)
      %(<div class="datalog-statement datalog-statement--#{@kind}" role="group" aria-labelledby="#{id}-heading" ) +
        %(id="#{id}" data-ref-target="#{id}" data-ref-kind="#{@kind}"#{number}>) +
        %(<p class="datalog-statement__heading" id="#{id}-heading">) +
        %(<span class="datalog-ref-label" data-ref-for="#{id}" data-ref-end=""></span>#{title}.</p>) +
        %(<div class="datalog-statement__body">#{body.strip}</div></div>\n)
    end
  end

  class ProofTag < Liquid::Block
    def initialize(tag_name, markup, options)
      super
      @markup = markup
    end

    def render(context)
      attributes = References.attributes(@markup, context, "proof")
      target = attributes["for"]
      body = References.markdown(context, super)
      heading_id = "proof-#{target ? References.validate_id(target, 'proof') : Statements.next_proof(context)}"
      heading = if target
                  link = %(<a class="datalog-ref" href="##{target}" data-ref="#{target}">#{target}</a>)
                  I18n.translate(context, "references.proof_of", "target" => link)
                else
                  CGI.escapeHTML(I18n.translate(context, "references.proof"))
                end
      end_mark = %(<p class="datalog-proof__end"><span aria-hidden="true">∎</span></p>)
      end_mark = "" if attributes["qed"] == "false"

      %(<div class="datalog-proof" role="group" aria-labelledby="#{heading_id}">) +
        %(<p class="datalog-proof__heading" id="#{heading_id}">#{heading}.</p>) +
        %(<div class="datalog-proof__body">#{body.strip}</div>#{end_mark}</div>\n)
    end
  end

  module Statements
    module_function

    KINDS = %w[theorem lemma proposition corollary definition assumption example remark].freeze

    # Proofs without a statement are numbered in the page for their heading ids only.
    def next_proof(context)
      context.registers[:datalog_proofs] = context.registers[:datalog_proofs].to_i + 1
    end
  end
end

Datalog::Statements::KINDS.each { |kind| Liquid::Template.register_tag(kind, Datalog::StatementTag) }
Liquid::Template.register_tag("proof", Datalog::ProofTag)
