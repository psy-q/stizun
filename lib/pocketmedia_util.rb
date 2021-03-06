# encoding: utf-8
require 'supplier_util'

class PocketmediaUtil < SupplierUtil

  def initialize
    @supplier = Supplier.where(:name => 'Pocketmedia').first
    if @supplier.nil?
      @supplier = Supplier.new
      @supplier.name = "Pocketmedia"
      @supplier.save
    end
    #0         1            2           3             4            5           6
    #ArtikelNr;HerstellerNr;Bezeichnung;Einkaufspreis;Lagerbestand;Lieferdatum;LieferdatumText;
    #7       8   9             10    11         12         13
    #Gewicht;EAN;Verkaufspreis;Marke;Kategorie1;Kategorie2;Details
    #
    # Sample row:
    # 90 60 0008;Papillon;"Handeld TV, 4.3"", DVB-T, Record, Video, Audio, Touch";0;10;40962;ab Lager;1;7.64E+12;199;Sayva;Fernseher;DVB-T;"4.3"""
    @field_mapping = {:name01 => 2, 
                      :name02 => nil,
                      :name03 => nil,
                      :description01 => 13,
                      :description02 => nil,
                      :supplier_product_code => 0,
                      :price_excluding_vat => 3,
                      :stock_level => 4,
                      :manufacturer_product_code => 1,
                      :manufacturer => 10,
                      :weight => 7,
                      :pdf_url => nil,
                      :product_link => nil,
                      :category01 => 11,
                      :category02 => 12,
                      :category03 => nil,
                      :ean_code => 8
                      }

    # Possible options:
    #   :col_sep => the separator character to split() on
    @csv_parse_options = { :col_sep => ";", :quote_char => '"' }
  end

  def self.data_directory
    return Rails.root + "lib"
  end

  # Synchronize all supply items from a supplier's provided CSV file
  def import_supply_items(filename)
    super
  end

  # Take all the raw data about a supply item and return a nice, meaningful string for its name, which can
  # be different between suppliers and is therefore handled in the supplier-specific subclasses
  def construct_supply_item_name(data)
    @supply_item_name = "#{data[:manufacturer]}"
    @supply_item_name += " #{data[:manufacturer_product_code]}" unless data[:manufacturer_product_code].blank?
    @supply_item_name += " (#{data[:ean_code]})" unless data[:ean_code].blank?
    super
  end

  def construct_supply_item_description(data)
    @description = data[:name01]
    super
  end

end
