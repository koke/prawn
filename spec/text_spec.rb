# encoding: utf-8

require File.join(File.expand_path(File.dirname(__FILE__)), "spec_helper")   

describe "Font Metrics" do  

  it "should default to Helvetica if no font is specified" do
    @pdf = Prawn::Document.new
    @pdf.font.metrics.should == Prawn::Font::Metrics["Helvetica"]
  end

  it "should use the currently set font for font_metrics" do
    @pdf = Prawn::Document.new
    @pdf.font "Courier"
    @pdf.font.metrics.should == Prawn::Font::Metrics["Courier"]
   
    comicsans = "#{Prawn::BASEDIR}/data/fonts/comicsans.ttf"
    @pdf.font(comicsans)
    @pdf.font.metrics.should == Prawn::Font::Metrics[comicsans]
  end

end    

describe "font style support" do
  before(:each) { create_pdf }
  
  it "should allow specifying font style by style name and font family" do    
    @pdf.font "Courier", :style => :bold
    @pdf.text "In Courier bold"    
    
    @pdf.font "Courier", :style => :bold_italic
    @pdf.text "In Courier bold-italic"   
     
    @pdf.font "Courier", :style => :italic
    @pdf.text "In Courier italic"    
    
    @pdf.font "Courier", :style => :normal
    @pdf.text "In Normal Courier"  
           
    @pdf.font "Helvetica"
    @pdf.text "In Normal Helvetica"     
    
    text = PDF::Inspector::Text.analyze(@pdf.render)
    text.font_settings.map { |e| e[:name] }.should == 
     [:"Courier-Bold", :"Courier-BoldOblique", :"Courier-Oblique", 
      :Courier, :Helvetica]
 end
      
end

describe "when drawing text" do     
   
   before(:each) { create_pdf } 

   it "should advance down the document based on font_height" do
     position = @pdf.y
     @pdf.text "Foo"

     @pdf.y.should.be.close(position - @pdf.font.height, 0.0001)

     position = @pdf.y
     @pdf.text "Foo\nBar\nBaz"
     @pdf.y.should.be.close(position - 3*@pdf.font.height, 0.0001)
   end
   
   it "should default to 12 point helvetica" do
      @pdf.text "Blah", :at => [100,100]              
      text = PDF::Inspector::Text.analyze(@pdf.render)  
      text.font_settings[0][:name].should == :Helvetica
      text.font_settings[0][:size].should == 12   
      text.strings.first.should == "Blah"
   end   
   
   it "should allow setting font size" do
     @pdf.text "Blah", :at => [100,100], :size => 16
     text = PDF::Inspector::Text.analyze(@pdf.render)  
     text.font_settings[0][:size].should == 16
   end
   
   it "should allow setting a default font size" do
     @pdf.font.size = 16
     @pdf.text "Blah"
     text = PDF::Inspector::Text.analyze(@pdf.render)  
     text.font_settings[0][:size].should == 16
   end
   
   it "should allow overriding default font for a single instance" do
     @pdf.font.size = 16

     @pdf.text "Blah", :size => 11
     @pdf.text "Blaz"
     text = PDF::Inspector::Text.analyze(@pdf.render)  
     text.font_settings[0][:size].should == 11
     text.font_settings[1][:size].should == 16
   end
   
   
   it "should allow setting a font size transaction with a block" do
     @pdf.font.size 16 do
       @pdf.text 'Blah'
     end

     @pdf.text 'blah'

     text = PDF::Inspector::Text.analyze(@pdf.render)  
     text.font_settings[0][:size].should == 16
     text.font_settings[1][:size].should == 12
   end
   
   it "should allow manual setting the font size " +
       "when in a font size block" do
     @pdf.font.size(16) do
        @pdf.text 'Foo'
        @pdf.text 'Blah', :size => 11
        @pdf.text 'Blaz'
      end
      text = PDF::Inspector::Text.analyze(@pdf.render)  
      text.font_settings[0][:size].should == 16
      text.font_settings[1][:size].should == 11
      text.font_settings[2][:size].should == 16
   end
      
   it "should allow registering of built-in font_settings on the fly" do
     @pdf.font "Times-Roman"
     @pdf.text "Blah", :at => [100,100]
     @pdf.font "Courier"                    
     @pdf.text "Blaz", :at => [150,150]
     text = PDF::Inspector::Text.analyze(@pdf.render)                      
     text.font_settings[0][:name].should == :"Times-Roman"  
     text.font_settings[1][:name].should == :Courier
   end   

   it "should utilise the same default font across multiple pages" do
     @pdf.text "Blah", :at => [100,100]
     @pdf.start_new_page
     @pdf.text "Blaz", :at => [150,150]
     text = PDF::Inspector::Text.analyze(@pdf.render)  

     text.font_settings.size.should  == 2
     text.font_settings[0][:name].should == :Helvetica
     text.font_settings[1][:name].should == :Helvetica
   end
   
   it "should raise an exception when an unknown font is used" do
     lambda { @pdf.font "Pao bu" }.should.raise(Prawn::Errors::UnknownFont)
   end

   it "should correctly render a utf-8 string when using a built-in font" do
     str = "©" # copyright symbol
     @pdf.text str

     # grab the text from the rendered PDF and ensure it matches
     text = PDF::Inspector::Text.analyze(@pdf.render)
     text.strings.first.should == str
   end
                    
   if "spec".respond_to?(:encode!)
     # Handle non utf-8 string encodings in a sane way on M17N aware VMs
     it "should raise an exception when a utf-8 incompatible string is rendered" do
       str = "Blah \xDD"
       str.force_encoding("ASCII-8BIT")
       lambda { @pdf.text str }.should.raise(Prawn::Errors::IncompatibleStringEncoding)
     end
     it "should not raise an exception when a shift-jis string is rendered" do 
       datafile = "#{Prawn::BASEDIR}/data/shift_jis_text.txt"  
       sjis_str = File.open(datafile, "r:shift_jis") { |f| f.gets } 
       @pdf.font("#{Prawn::BASEDIR}/data/fonts/gkai00mp.ttf")
       lambda { @pdf.text sjis_str }.should.not.raise(Prawn::Errors::IncompatibleStringEncoding)
     end
   else
     # Handle non utf-8 string encodings in a sane way on non-M17N aware VMs
     it "should raise an exception when a corrupt utf-8 string is rendered" do
       str = "Blah \xDD"
       lambda { @pdf.text str }.should.raise(Prawn::Errors::IncompatibleStringEncoding)
     end
     it "should raise an exception when a shift-jis string is rendered" do
       sjis_str = File.read("#{Prawn::BASEDIR}/data/shift_jis_text.txt")
       lambda { @pdf.text sjis_str }.should.raise(Prawn::Errors::IncompatibleStringEncoding)
     end
   end 

end
