# frozen_string_literal: true

require_relative "authors"
require_relative "i18n"
require_relative "image_optimizer"
require_relative "../lib/datalog/social_cards"

# Draws the share cards after every other generator, so the pages that
# generators add are there, and the series and authors are resolved.
class Datalog::SocialCardsGenerator < Jekyll::Generator
  safe true
  priority :lowest

  def generate(site)
    Datalog::SocialCards.generate(site)
  end
end
