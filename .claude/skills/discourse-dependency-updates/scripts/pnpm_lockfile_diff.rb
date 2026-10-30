#!/usr/bin/env ruby
# frozen_string_literal: true

# Lists package versions added to or removed from pnpm-lock.yaml.
#
# Usage: pnpm_lockfile_diff.rb BASE_REF [HEAD_REF]
#
# Without HEAD_REF, compares against the working tree.

base, head = ARGV
abort "Usage: pnpm_lockfile_diff.rb BASE_REF [HEAD_REF]" unless base

def lockfile(ref)
  return File.read("pnpm-lock.yaml") if ref.nil?
  IO
    .popen(["git", "show", "#{ref}:pnpm-lock.yaml"], &:read)
    .tap { abort "Could not read pnpm-lock.yaml at #{ref}" unless $?.success? }
end

# pnpm 12 lockfiles start with a document that pins pnpm itself, so use the last `packages:` section.
def packages(text)
  section = text.split(/^packages:\n/).last.split(/^snapshots:\n/).first
  section.scan(/^  '?(\S.*?)'?:\s*$/).flatten.to_set
end

before = packages(lockfile(base))
after = packages(lockfile(head))

(before - after).sort.each { |pkg| puts "- #{pkg}" }
(after - before).sort.each { |pkg| puts "+ #{pkg}" }
