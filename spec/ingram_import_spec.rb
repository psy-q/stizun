# encoding: utf-8

require 'spec_helper'
require_relative '../lib/ingram_util'

describe IngramUtil do
  before(:each) do
    describe "at the start of the tests, the system" do
      it "should have no supply items" do
        SupplyItem.count.should == 0
      end

      it "should have a supplier called 'Ingram Micro GmbH'" do
        supplier = Supplier.find_or_create_by_name(:name => "Ingram Micro GmbH")
        supplier.name.should == "Ingram Micro GmbH"
      end
    end
  end

  describe "importing supply items from CSV" do
    it "should import 370 items" do
      IngramTestHelper.import_from_file(Rails.root + "spec/data/370_im_products.csv")
      SupplyItem.count.should == 370
      supplier = Supplier.where(:name => 'Ingram Micro GmbH').first

      supply_item_should_be(supplier, "0180631", { :manufacturer => 'Dymo',
                                                :weight => 0.05,
                                                :purchase_price => 15.30,
                                                :stock => 41} )

      supply_item_should_be(supplier, "0180538", { :manufacturer => 'Dymo',
                                                :weight => 0.23,
                                                :purchase_price => 18.70,
                                                :stock => 110} )

      supply_item_should_be(supplier, "018Z055", { :manufacturer => 'Dymo',
                                                :weight => 0.06,
                                                :purchase_price => 16.70,
                                                :stock => 33} )

      supply_item_should_be(supplier, "0711186", { :manufacturer => 'Netgear',
                                                :weight => 8.21,
                                                :purchase_price => 863.80,
                                                :stock => 0} )

    end

    it "should change items when they have changed in the CSV file" do
      SupplyItem.count.should == 0
      IngramTestHelper.import_from_file(Rails.root + "spec/data/370_im_products.csv")
      SupplyItem.count.should == 370

      codes = ["0180631","0180538","018Z055","0711186"]
      codes.each do |code|
          supply_item = SupplyItem.where(:supplier_product_code => code).first
          product = Product.new_from_supply_item(supply_item)
          product.save.should == true
      end
      IngramTestHelper.update_from_file(Rails.root + "spec/data/370_im_products_with_4_changes.csv")
      SupplyItem.count.should == 370

      supplier = Supplier.where(:name => 'Ingram Micro GmbH').first

      supply_item_should_be(supplier, "0180631", { :manufacturer => 'Dymo',
                                                :weight => 0.10,
                                                :purchase_price => 15.30,
                                                :stock => 41} )

      supply_item_should_be(supplier, "0180538", { :manufacturer => 'Dymo',
                                                :weight => 0.23,
                                                :purchase_price => 19.70,
                                                :stock => 110} )

      supply_item_should_be(supplier, "018Z055", { :manufacturer => 'Dymo',
                                                :weight => 0.06,
                                                :purchase_price => 16.70,
                                                :stock => 100} )

      supply_item_should_be(supplier, "0711186", { :manufacturer => 'Netgear',
                                                :weight => 12.4,
                                                :purchase_price => 1233.40,
                                                :stock => 15} )

    end

    it "should mark items as deleted when they were removed from the CSV file" do
      SupplyItem.count.should == 0
      IngramTestHelper.import_from_file(Rails.root + "spec/data/370_im_products.csv")
      SupplyItem.count.should == 370

      supplier = Supplier.where(:name => 'Ingram Micro GmbH').first
      product_codes = ["0711642", "0712027", "0712259", "0712530", "0712577", "07701A5", "07701F4", "07702U8", "07702V2", "0770987"]

      # Create products so only those get updated/marked deleted
      # product_codes.each do |code|
      #   supply_item = SupplyItem.where(:supplier_product_code => code).first
      #   product = Product.new_from_supply_item(supply_item)
      #   product.save.should == true
      # end

      IngramTestHelper.update_from_file(Rails.root + "spec/data/360_im_products.csv")
      SupplyItem.count.should == 370 # but 10 of them marked deleted
      # The others should *not* be deleted
      SupplyItem.available.where(:supplier_id => supplier).count.should == 360

      ids = SupplyItem.where(:supplier_product_code => product_codes, :supplier_id => supplier).collect(&:id)
      supply_items_should_be_marked_deleted(ids, supplier)

    end

    it "should disable products whose supply items were removed" do
      IngramTestHelper.import_from_file(Rails.root + "spec/data/370_im_products.csv")
      supply_item = SupplyItem.where(:supplier_product_code => "0712259").first
      product = Product.new_from_supply_item(supply_item)
      product.save.should == true
      product.available?.should == true
      IngramTestHelper.update_from_file(Rails.root + "spec/data/360_im_products.csv")
      supply_item.reload
      supply_item.status_constant.should == SupplyItem::DELETED

      product.reload
      product.available?.should == false

    end

    # *Supply Item, das einst "not available" war, erscheint wieder im CSV-File*
    it "should re-enable products if their supply items become available again" do
      IngramTestHelper.import_from_file(Rails.root + "spec/data/supply_item_reappears_01.csv")
      sup1 = SupplyItem.where(:supplier_product_code => "0180009").first
      sup2 = SupplyItem.where(:supplier_product_code => "0180014").first

      prod1 = Product.new_from_supply_item(sup1)
      prod1.save
      prod2 = Product.new_from_supply_item(sup2)
      prod2.save

      IngramTestHelper.update_from_file(Rails.root + "spec/data/supply_item_reappears_02.csv")

      sup1.status_constant.should == SupplyItem::AVAILABLE
      sup2.reload
      sup2.status_constant.should == SupplyItem::DELETED
      
      prod1.reload.is_available.should == true
      prod2.reload.is_available.should == false

      IngramTestHelper.update_from_file(Rails.root + "spec/data/supply_item_reappears_03.csv")

      sup1.status_constant.should == SupplyItem::AVAILABLE
      sup2.reload
      sup2.status_constant.should == SupplyItem::AVAILABLE
      
      prod1.reload.is_available.should == true
      prod2.reload.is_available.should == true
    end

    # *Supply Item erhält danach wieder Stückzahl über 0*
    it "should re-enable products if their stock count goes over 0 again" do
      IngramTestHelper.import_from_file(Rails.root + "spec/data/supply_item_stock_comes_back_above_zero_01.csv")
      sup = SupplyItem.where(:supplier_product_code => "0180009").first
      prod = Product.new_from_supply_item(sup)
      prod.save

      IngramTestHelper.update_from_file(Rails.root + "spec/data/supply_item_stock_comes_back_above_zero_02.csv")
      sup.reload
      sup.stock.should == 0

      Product.update_price_and_stock
      prod.reload
      prod.stock.should == 0
      prod.is_available.should == true # It's available, but with 0 in stock

      IngramTestHelper.update_from_file(Rails.root + "spec/data/supply_item_stock_comes_back_above_zero_03.csv")
      sup.reload
      sup.stock.should == 12

      Product.update_price_and_stock

      prod.reload
      prod.stock.should == 12
      prod.is_available.should == true
    end

    it "should check if a changed price makes a supply item cheaper than an existing one, then it should change the product to that" do

      # The item 123XXX45 costs 5.00 at both places at the moment
      IngramTestHelper.import_from_file(Rails.root + "spec/data/supply_item_price_change_makes_it_the_cheaper_option_01_ingram.csv")
      AlltronTestHelper.import_from_file(Rails.root + "spec/data/supply_item_price_change_makes_it_the_cheaper_option_01_alltron.csv")
      
      ingram = Supplier.where(:name => 'Ingram Micro GmbH').first
      alltron = Supplier.where(:name => 'Alltron AG').first
      sup = ingram.supply_items.where(:manufacturer_product_code => "123XXX45").first
      prod = Product.new_from_supply_item(sup)
      prod.save
      prod.purchase_price.to_f.should == 5.0

      AlltronTestHelper.update_from_file(Rails.root + "spec/data/supply_item_price_change_makes_it_the_cheaper_option_02_alltron.csv")
      sup_alltron = alltron.supply_items.where(:manufacturer_product_code => "123XXX45").first
      sup_alltron.purchase_price.to_f.should == 2.0


      Product.update_price_and_stock
      # The product should have switched itself to this new option, the cheaper supply item from Alltron
      prod.reload
      prod.supplier.should == alltron
      prod.supply_item.should == sup_alltron
      prod.purchase_price.to_f.should == 2.0


      # Product.update_price_and_stock
      # prod.reload
      # prod.stock.should == 0
      # prod.is_available.should == true # It's available, but with 0 in stock

    end

  end
end
