require 'bai2/version'
require 'bai2/record'

module Bai2


  # This class is the main wrapper around a Bai2 file.
  #
  class BaiFile < RecordFieldAccessor.new(:file_header)

    # TODO:
    # - run checksums

    # Parse a file on disk:
    #
    #   f = BaiFile.parse('myfile.bai2')
    #
    def self.parse(path)
      self.new(File.read(path))
    end


    # Parse a Bai2 data buffer:
    #
    #   f = BaiFile.new(bai2_data)
    #
    def initialize(raw)
      @raw = raw
      @groups = []
      parse(raw)
    end

    # This is the raw data. Probably not super important.
    attr_reader :raw

    # The groups contained within this file.
    attr_reader :groups



    # =========================================================================
    # Parsing implementation
    #

    class ParseError < Exception; end

    private



    # Parsing is a two-step process:
    #
    # 1. Build a tree
    # 2. Parse the tree
    #
    def parse(data)

      # split records, handle stupid DOS-format files, instantiate records
      records = data.split("\n").map(&:chomp).map {|l| Record.new(l) }

      # build the tree
      @root = parse_tree(records)

      # parse the file node; will descend tree and parse children
      parse_file_node(@root)

    end


    # Wrapper object to represent a tree node.
    #
    class ParseNode

      def initialize(record)
        @code, @records = record.code, [record]
        @children = []
      end
      attr_reader :code
      attr_accessor :records, :children


      def push_record(record)
        self
      end

      private
      def parse_record(record)
      end
    end


    # Builds the tree of nodes
    #
    def parse_tree(records)

      # build tree, should return a file_header node
      first, *records = *records
      unless first.code == :file_header
        raise ParseError.new('Expecting file header record (01).')
      end
      root = ParseNode.new(first)
      stack = [root]

      records.each do |record|
        raise ParseError.new('Unexpected record.') if stack.empty?

        case record.code

          # handling headers
        when :group_header, :account_identifier

          parent = {group_header:       :file_header,
                    account_identifier: :group_header}[record.code]
          unless stack.last.code == parent
            raise ParseError.new("Parsing #{record.code}, expecting #{parent} parent.")
          end

          n = ParseNode.new(record)
          stack.last.children << n
          stack << n

          # handling trailers
        when :account_trailer, :group_trailer, :file_trailer

          parent = {account_trailer: :account_identifier,
                    group_trailer:   :group_header,
                    file_trailer:    :file_header}[record.code]
          unless stack.last.code == parent
            raise ParseError.new("Parsing #{record.code}, expecting #{parent} parent.")
          end

          stack.last.records << record
          stack.pop

          # handling continuations
        when :continuation

          n = (stack.last.children.last || stack.last)
          n.records << record

          # handling transactions
        when :transaction_detail

          unless stack.last.code == :account_identifier
            raise ParseError.new("Parsing #{record.code}, expecting account_identifier parent.")
          end

          stack.last.children << ParseNode.new(record)

          # handling special known errors
        else # nil
          binding.pry
          raise ParseError.new('Unknown or unexpected record code.')
        end
      end

      unless stack == []
        raise ParseError.new('Reached unexpected end of input (EOF).')
      end

      # root now contains our parsed tree
      root
    end

    # Parses the file_header root tree node, and creates the object hierarchy.
    #
    def parse_file_node(n)

      unless n.code == :file_header && n.records.count == 2 && \
          n.records.map(&:code) == [:file_header, :file_trailer]
        raise ParseError.new('Unexpected record.')
      end

      head, tail = *n.records

      @groups = n.children.map {|child| Group.send(:parse, child) }
    end


    public

    # TODO: write me; finish me
    class Group < RecordFieldAccessor.new(:group_header)

      def initialize
        @accounts = []
      end

      attr_reader :accounts

      private

      def parse(n)

        unless n.code == :group_header && \
            n.records.map(&:code) == [:group_header, :group_trailer]
          raise BaiFile::ParseError.new('Unexpected record.')
        end

        @accounts = n.children.map {|child| Account.send(:parse, child) }
      end

    end


    class Account < RecordFieldAccessor.new(:account_identifier)

      def initialize
        @transactions = []
      end

      attr_reader :transactions

      private

      def parse(n)

        unless n.code == :account_identifier && \
            n.records.map(&:code) == [:account_identifier, :account_trailer]
          raise BaiFile::ParseError.new('Unexpected record.')
        end

        @transactions = n.children.map {|child| Transaction.parse(child) }
      end

    end


    class Transaction < RecordFieldAccessor.new(:transaction_detail)

      attr_reader :text

      private

      def parse(n)
        record, continuations = *n.records
      end

    end

  end # BaiFile


end