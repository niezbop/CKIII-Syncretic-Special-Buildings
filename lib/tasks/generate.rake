require 'dotenv/tasks'
require 'json'
require 'clausewitz'
require_relative 'helpers/block_refiner'

LAUNCHER_SETTINGS_PATH = File.join('launcher', 'launcher-settings.json').freeze
SPECIAL_BUILDINGS_PATH = File.join('game', 'common', 'buildings', '00_special_buildings.txt').freeze

def launcher_settings_path
  File.join(ENV['GAME_FILES_PATH'], LAUNCHER_SETTINGS_PATH)
end

def launcher_settings
  File.read(launcher_settings_path)
end

def game_version
  JSON.parse(launcher_settings)['rawVersion']
end

def special_buildings_path
  File.join(ENV['GAME_FILES_PATH'], SPECIAL_BUILDINGS_PATH)
end

def find_child_by_name(block, name)
  block.children.find { |c| c&.left&.name == name }
end

def find_filler_tokens(from, to)
  filler = []
  token = from
  loop do
    token = token.next_token
    break if token == to
    if token.ignorable?
      filler << token
    else
      filler = []
    end
  end
  return filler
end

def duplicate_token(token)
  return Clausewitz::Lexing::Token.new(
    name: token.name,
    value: token.value,
    location: token.location.dup, # Currently meaningless
    ignorable: token.ignorable?)
end

def duplicate_tokens(tokens) 
  current_token = nil
  return tokens.map do |token|
    duplicata = duplicate_token(token)
    current_token.append(duplicata) unless current_token.nil?
    current_token = duplicata
    duplicata
  end
end

def fake_token(value)
  return Clausewitz::Lexing::Token.new(
    name: :FAKE,
    value: value,
    location: Clausewitz::Lexing::Token::Location.new(line: 0, column: 0, length: 0),
    ignorable: false)
end

desc 'Copy the special buildings for reference'
task reference: :dotenv do
  version_ref = File.join('ref', game_version)
  FileUtils.mkdir_p(version_ref)
  FileUtils.cp(special_buildings_path, version_ref)
end

desc 'Generates the folder from game files'
task generate: :dotenv do
  using BlockRefiner
  include Clausewitz::Parsing::Tree

  vanilla_buildings = Clausewitz.parse(File.read special_buildings_path)
  vanilla_buildings.children.each do |child_statement|
    building_name = child_statement.left.name
    # puts building_name

    building_block = child_statement.right

    can_construct_block = find_child_by_name(building_block, 'can_construct')

    next if can_construct_block.nil?

    religion_checks = can_construct_block.right.recursive_children.select do |parentage|
      parentage.last.left.name == 'religion'
    end

    next if religion_checks.none?

    puts '#==========================='
    puts building_name

    religion_checks.each do |parentage|
      religion_check = parentage[-1]
      first_parent = parentage[-2]
      puts '+----------------------'
      puts first_parent.left.name
      puts religion_check.right.name

      parent_to_check = find_filler_tokens(first_parent.first_token,
                                           religion_check.first_token)
      has_linebreak = parent_to_check.any? {|t| t.name == :LINE_BREAK }

      # Religion check direct preceding token is parent_to_check.last
      # Religion check direct following token is religion_check.last_token.next_token
      if first_parent&.left&.name != 'OR'
        # TODO: Create OR parent
        or_statement = Statement.new(
          Identifier.new('OR'),
          Block.new)
        # Emulate token list
        [
          fake_token('OR = {'),
          duplicate_tokens(parent_to_check),
          fake_token(has_linebreak ? "\t" : ' '),
          religion_check.first_token
        ].flatten.reduce(parent_to_check.last) do |last_token, token|
          last_token.append(token)
          last_token = token
        end

        [
          duplicate_tokens(parent_to_check),
          fake_token('}'),
          religion_check.last_token.next_token
        ].flatten.reduce(religion_check.last_token) do |last_token, token|
          last_token.append(token)
          last_token = token
        end
      end

      # TODO: Insert syncretic check below religion check
    end
  end

  File.open('output.txt', 'w') do |file|
    serializer = Clausewitz::Serializing::Serializer.new
    token_list = Clausewitz::Lexing::TokenList.new(head_token: vanilla_buildings.first_token)
    serializer.serialize(token_list, io: file)
  end
end
