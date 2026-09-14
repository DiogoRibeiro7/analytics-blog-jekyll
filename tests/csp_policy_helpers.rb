# frozen_string_literal: true

# Reads a built page's Content Security Policy, for the CSP tests.
module CspPolicyHelpers
  # The page's Content-Security-Policy meta tag as a map of directive to sources.
  def policy_directives(html)
    policy = html[/<meta http-equiv="Content-Security-Policy" content="([^"]*)"/, 1].to_s
    policy.split(";").each_with_object({}) do |directive, directives|
      name, *sources = directive.split
      directives[name] = sources if name
    end
  end
end
