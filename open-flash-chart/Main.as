
package  {
	import charts.Elements.Element;
	import charts.Factory;
	import charts.ObjectCollection;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.display.Sprite;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import string.Utils;
	import global.Global;
	import com.serialization.json.JSON;
	import flash.external.ExternalInterface;
	import flash.ui.ContextMenu;
	import flash.ui.ContextMenuItem;
	import flash.events.IOErrorEvent;
	import flash.events.ContextMenuEvent;
	import flash.system.System;
	
	// export the chart as an image
	import com.adobe.images.PNGEncoder;
	import com.adobe.images.JPGEncoder;
	import mx.utils.Base64Encoder;
	// import com.dynamicflash.util.Base64;
	import flash.display.BitmapData;
	import flash.utils.ByteArray;
	import flash.net.URLRequestHeader;
	import flash.net.URLRequestMethod;
	import flash.net.URLLoaderDataFormat;
	import elements.axis.XAxis;
	import elements.axis.XAxisLabels;
	import elements.axis.YAxisBase;
	import elements.axis.YAxisLeft;
	import elements.axis.YAxisRight;
	import elements.axis.RadarAxis;
	import elements.Background;
	import elements.labels.XLegend;
	import elements.labels.Title;
	import elements.labels.Keys;
	import elements.labels.YLegendBase;
	import elements.labels.YLegendLeft;
	import elements.labels.YLegendRight;
	import elements.ChartBackground;
	import elements.ChartOverlay;
	
	public class Main extends Sprite {
		public  var VERSION:String = "2 Hyperion";
		private var title:Title = null;
		private var x_labels:XAxisLabels;
		private var x_axis:XAxis;
		private var chart_background:ChartBackground;
		private var chart_overlay:ChartOverlay;
		CONFIG::enable_radar {
		  private var radar_axis:RadarAxis;
		}
		private var x_legend:XLegend;
		private var y_axis:YAxisBase;
		private var y_axis_right:YAxisBase;
		private var y_legend:YLegendBase;
		private var y_legend_2:YLegendBase;
		private var keys:Keys;
		private var obs:ObjectCollection;
		public var tool_tip_wrapper:String;
		private var tooltip:Tooltip;
		private var background:Background;
		private var ok:Boolean;
		private var URL:String;		// ugh, vile. The IOError doesn't report the URL
		private var chart_parameters:Object;
		
		public function Main(parameters:Object) {	  
			chart_parameters = parameters;

			this.ok = false;

			if( !this.find_data() )
			{
				// no data found -- debug mode?
				try {
					var file:String = "../../../test-data-files/pie-chart-alpha-bug.txt";
					this.load_external_file( file );

					/*
					// test AJAX calls like this:
					var file:String = "../data-files/bar-2.txt";
					this.load_external_file( file );
					file = "../data-files/radar-area.txt";
					this.load_external_file( file );
					*/
				}
				catch (e:Error) {
					this.show_error( 'Loading data\n'+file+'\n'+e.message );
				}
			}
		}
		
		public function init():void {
      // YMO Change
      CONFIG::enable_context_menu {
  			 this.build_right_click_menu();        
      }

		  // inform javascript that it can call our load method
			CONFIG::enable_external_interface {
			  ExternalInterface.addCallback("load", load);
			
  			CONFIG::enable_save_image {
			    // inform javascript that it can call our post_image method
    			ExternalInterface.addCallback("post_image", post_image);
      		// 
      		ExternalInterface.addCallback("get_img_binary",  getImgBinary);
  		  }
		  
  			// more interface			
  			ExternalInterface.addCallback("get_version",	getVersion);
			
  			// tell the web page that we are ready
  			if( this.chart_parameters['id'] )
  				ExternalInterface.call("ofc_ready", this.chart_parameters['id']);
  			else
  				ExternalInterface.call("ofc_ready");
			}
			this.set_the_stage();
		}
		
		public function getVersion():String {return VERSION;}
		
		CONFIG::enable_save_image
		public function getImgBinary():String {
		  CONFIG::debug { tr.ace('Saving image :: image_binary()'); }
      
			var bmp:BitmapData = new BitmapData(this.stage.stageWidth, this.stage.stageHeight);
			bmp.draw(this);
			
			var b64:Base64Encoder = new Base64Encoder();
			
			var b:ByteArray = PNGEncoder.encode(bmp);
			
			// var encoder:JPGEncoder = new JPGEncoder(80);
			// var q:ByteArray = encoder.encode(bmp);
			// b64.encodeBytes(q);
			
			b64.encodeBytes(b);
			return b64.flush();
			
			/*
			var b64:Base64Encoder = new Base64Encoder();
			b64.encodeBytes(image_binary());
			CONFIG::debug { tr.ace( b64 as String ); }
			return b64 as String;
			*/
		}
		
		
		/**
		 * Called from the context menu:
		 */
 		CONFIG::enable_save_image
		public function saveImage(e:ContextMenuEvent):void {
			// ExternalInterface.call("save_image", this.chart_parameters['id']);// , getImgBinary());
			// ExternalInterface.call("save_image", getImgBinary());
			
			// this just calls the javascript function which will grab an image from use
			// an do something with it.
			CONFIG::enable_external_interface {
			  ExternalInterface.call("save_image");
		  }
		}

		CONFIG::enable_save_image
	  private function image_binary() : ByteArray {
			CONFIG::debug { tr.ace('Saving image :: image_binary()'); }
			var pngSource:BitmapData = new BitmapData(this.width, this.height);
			pngSource.draw(this);
			return PNGEncoder.encode(pngSource);
	  }
	
		//
		// External interface called by Javascript to
		// save the flash as an image, then POST it to a URL
		//
		CONFIG::enable_save_image
		public function post_image( url:String, callback:String, debug:Boolean ):void {
			
			var header:URLRequestHeader = new URLRequestHeader("Content-type", "application/octet-stream");

			//Make sure to use the correct path to jpg_encoder_download.php
			var jpgURLRequest:URLRequest = new URLRequest(url);
			
			jpgURLRequest.requestHeaders.push(header);
			jpgURLRequest.method = URLRequestMethod.POST;
			jpgURLRequest.data = image_binary();

			if( CONFIG::debug && debug )
			{
				// debug the PHP:
				flash.net.navigateToURL(jpgURLRequest, "_blank");
			}
			else
			{
				var loader:URLLoader = new URLLoader();
				loader.dataFormat = URLLoaderDataFormat.BINARY;
				CONFIG::enable_external_interface {  		  
  				loader.addEventListener(Event.COMPLETE, function(e:Event):void {
  					CONFIG::debug { tr.ace('Saved image to:'); }
  					CONFIG::debug { tr.ace( url ); }
  					//
  					// when the upload has finished call the user
  					// defined javascript function/method
  					//
  					ExternalInterface.call(callback);
  					});
				}
				
				loader.load( jpgURLRequest );
			}
		}

		CONFIG::enable_context_menu
		private function onContextMenuHandler(event:ContextMenuEvent):void
		{
		}
		
		//
		// try to find some data to load,
		// check the URL for a file name,
		//
		//
		public function find_data(): Boolean {
		  CONFIG::enable_external_interface {
  			// var all:String = ExternalInterface.call("window.location.href.toString");
  			var vars:String = ExternalInterface.call("window.location.search.substring", 1);

  			if( vars != null )
  			{
  				var p:Array = vars.split( '&' );
  				for each ( var v:String in p )
  				{
  					if( v.indexOf( 'ofc=' ) > -1 )
  					{
  						var tmp:Array = v.split('=');
  						CONFIG::debug { tr.ace( 'Found external file:' + tmp[1] ); }
  						this.load_external_file( tmp[1] );
  						//
  						// LOOK:
  						//
  						return true;
  					}
  				}
  			}		    
		  }
			
			if( this.chart_parameters['data-file'] )
			{
				// tr.ace( 'Found parameter:' + parameters['data-file'] );
				this.load_external_file( this.chart_parameters['data-file'] );
				//
				// LOOK:
				//
				return true;
				
			}
			
			var get_data:String = 'open_flash_chart_data';
			if( this.chart_parameters['get-data'] )
				get_data = this.chart_parameters['get-data'];
			
			var json_string:*;
			
			CONFIG::enable_external_interface {		  
  			if( this.chart_parameters['id'] )
  				json_string = ExternalInterface.call( get_data , this.chart_parameters['id']);
  			else
  				json_string = ExternalInterface.call( get_data );
			}
			
			if( json_string != null )
			{
				if( json_string is String )
				{
					this.parse_json( json_string );
					
					//
					// We have loaded the data, so this.ok = true
					//
					this.ok = true;
					//
					// LOOK:
					//
					return true;
				}
			}
			
			return false;
		}
		
		private function load_external_file( file:String ):void {
			
			this.URL = file;
			//
			// LOAD THE DATA
			//
			var loader:URLLoader = new URLLoader();
			loader.addEventListener( IOErrorEvent.IO_ERROR, this.ioError );
			loader.addEventListener( Event.COMPLETE, xmlLoaded );
			
			var request:URLRequest = new URLRequest(file);
			loader.load(request);
		}
		
		private function ioError( e:IOErrorEvent ):void {
			var msg:ErrorMsg = new ErrorMsg( 'Open Flash Chart\nIO ERROR\nLoading test data\n' + e.text );
			msg.add_html( 'This is the URL that I tried to open:<br><a href="'+this.URL+'">'+this.URL+'</a>' );
			this.addChild( msg );
		}
		
		private function show_error( msg:String ):void {
			var m:ErrorMsg = new ErrorMsg( msg );
			//m.add_html( 'Click here to open your JSON file: <a href="http://a.com">asd</a>' );
			this.addChild(m);
		}

		public function get_x_legend() : XLegend {
			return this.x_legend;
		}
		
		private function set_the_stage():void {
      this.stage.addEventListener(Event.ACTIVATE, this.activateHandler);
      this.stage.addEventListener(Event.RESIZE, this.resizeHandler);
			this.stage.addEventListener(Event.MOUSE_LEAVE, this.mouseOut);
			
			//
			// TODO: check and remove
			//
			//this.stage.addEventListener( ShowTipEvent.SHOW_TIP_TYPE, this.show_tip );
			//this.stage.addEventListener( ShowTipEvent.SHOW_TIP_TYPE, this.show_tip );
			//this.stage.addEventListener( Event..MIDDLE_CLICK, this.show_tip );
			
			this.addEventListener( MouseEvent.MOUSE_OVER, this.mouseMove );
		}
		
//		private function show_tip( event:ShowTipEvent ):void {
//			tr.ace( 'show_tip: over '+event.pos );
//		}
//		private function show_tip2( event:MouseEvent ):void {
//			
//			this.mouseMove( event );
//		}
		
		private function mouseMove( event:Event ):void {
			// tr.ace( 'over ' + event.target );
			// tr.ace('move ' + Math.random().toString());
			// tr.ace( this.tooltip.get_tip_style() );
  
      // YMO Prevent error when mousing over while loading.
      if (this.tooltip == null)
        return;
			
			switch( this.tooltip.get_tip_style() ) {
				case Tooltip.CLOSEST:
					this.mouse_move_closest( event );
					break;
					
				case Tooltip.PROXIMITY:
				  CONFIG::debug { tr.ace('prox'); }
					this.mouse_move_proximity( event as MouseEvent );
					break;
					
				case Tooltip.NORMAL:
					this.mouse_move_follow( event as MouseEvent );
					break;
					
			}
		}
		
		private function mouse_move_follow( event:MouseEvent ):void {
			//tr.ace( event.currentTarget );
			//tr.ace( event.target );
			
			if( event.target is Element )
				this.tooltip.draw( event.target as Element );
			else
				this.tooltip.hide();
		}
		
		private function mouse_move_proximity( event:MouseEvent ):void {
			//tr.ace( event.currentTarget );
			//tr.ace( event.target );
			var elements:Array = this.obs.mouse_move_proximity( this.mouseX, this.mouseY );
			this.tooltip.closest( elements );
		}
		
		private function mouse_move_closest( event:Event ):void {
			var elements:Array = this.obs.closest_2( this.mouseX, this.mouseY );
			this.tooltip.closest( elements );
		}
		
		private function activateHandler(event:Event):void {
      CONFIG::debug { tr.ace("activateHandler: " + event); }
    }

    private function resizeHandler(event:Event):void {
        // //FlashConnect.trace("resizeHandler: " + event);
        this.resize();
    }

		//
		// pie charts are simpler to resize, they don't
		// have all the extras (X,Y axis, legends etc..)
		//
		CONFIG::enable_pie
		private function resize_pie(): ScreenCoordsBase {
			// should this be here?
			this.addEventListener(MouseEvent.MOUSE_MOVE, this.mouseMove);
			
			this.background.resize();
			this.title.resize();
			
			// this object is used in the mouseMove method
			var sc:ScreenCoords = new ScreenCoords(
				this.title.get_height(), 0, this.stage.stageWidth, this.stage.stageHeight,
				null, null, null, 0, 0, false, false, false );
			this.obs.resize( sc );
			
			return sc;
		}
		
		//
		//
		CONFIG::enable_radar
		private function resize_radar(): ScreenCoordsBase {
			this.addEventListener(MouseEvent.MOUSE_MOVE, this.mouseMove);
			
			this.background.resize();
			this.title.resize();
			this.keys.resize( 0, this.title.get_height() );
				
			var top:Number = this.title.get_height() + this.keys.get_height();
			
			// this object is used in the mouseMove method
			var sc:ScreenCoordsRadar = new ScreenCoordsRadar(top, 0, this.stage.stageWidth, this.stage.stageHeight);
			
			sc.set_max( this.radar_axis.get_max() );
			sc.set_angles( this.obs.get_max_x() );
			
			// resize the axis first because they may
			// change the radius (to fit the labels on screen)
			this.radar_axis.resize( sc );
			this.obs.resize( sc );
			
			return sc;
		}
		
		private function resize():void {
			//
			// the chart is async, so we may get this
			// event before the chart has loaded, or has
			// partly loaded
			//
			if ( !this.ok )
				return;			// <-- something is wrong
		
			var sc:ScreenCoordsBase;
			
			var got_it:Boolean = false;
			
			CONFIG::enable_radar {
			  if (this.radar_axis != null) {
				  sc = this.resize_radar();
				  got_it = true;
				}
			}
			CONFIG::enable_pie {
  			if (!got_it && this.obs.has_pie()) {
  				sc = resize_pie();
  				got_it = true;
				}			  
			}
			if (!got_it)
				sc = this.resize_chart();
			
			
			// tell the web page that we have resized our content
			CONFIG::enable_external_interface {
  			if(this.chart_parameters['id'])
  				ExternalInterface.call("ofc_resize", sc.left, sc.width, sc.top, sc.height, this.chart_parameters['id']);
  			else
  				ExternalInterface.call("ofc_resize", sc.left, sc.width, sc.top, sc.height);
			}
			
			sc = null;
		}
			
		private function resize_chart(): ScreenCoordsBase {
			//
			// we want to show the tooltip closest to
			// items near the mouse, so hook into the
			// mouse move event:
			//
			this.addEventListener(MouseEvent.MOUSE_MOVE, this.mouseMove);
	
			this.background.resize();
			this.title.resize();
			
			var left:Number   = this.y_legend.get_width() /*+ this.y_labels.get_width()*/ + this.y_axis.get_width();
			
			this.keys.resize(left, this.title.get_height());
				
			var top:Number = this.title.get_height() + this.keys.get_height();
			
			var bottom:Number = this.stage.stageHeight;
			bottom -= (this.x_labels.get_height() + this.x_legend.get_height() + this.x_axis.get_height());
			
			var right:Number = this.stage.stageWidth;
			right -= this.y_legend_2.get_width();
			//right -= this.y_labels_right.get_width();
			right -= this.y_axis_right.get_width();
			// Ensure the rightmost label fits. This is based on the kind of taken out of the air
			// assumption that at least half the label width will be inside the graph area. This
			// happens to be reasonable for YippieMove.
			right = Math.min(right, this.stage.stageWidth - this.x_labels.get_last_label().width/2);

			// this object is used in the mouseMove method
			var sc:ScreenCoords = new ScreenCoords(
				top, left, right, bottom,
				this.y_axis.get_range(),
				this.y_axis_right.get_range(),
				this.x_axis.get_range(),
				this.x_labels.first_label_width(),
				this.x_labels.last_label_width(),
				false,
				this.x_axis.offset, this.y_axis.offset );
			
			sc.set_bar_groups(this.obs.groups);
			
			this.x_labels.resize(
				sc,
				this.stage.stageHeight-(this.x_legend.get_height()+this.x_labels.get_height())	// <-- up from the bottom
				);
				
			this.chart_background.resize(sc);
			this.chart_overlay.resize(sc);
			this.x_axis.resize( sc );
			this.y_axis.resize( this.y_legend.get_width(), sc );
			this.y_axis_right.resize( 0, sc );
			this.x_legend.resize( sc );
			this.y_legend.resize();
			this.y_legend_2.resize();
				
			this.obs.resize( sc );
			
			return sc;
		}
		
		private function mouseOut(event:Event):void {		
			if( this.tooltip != null )
				this.tooltip.hide();
			
			if( this.obs != null )
				this.obs.mouse_out();
    }
		
		//
		// an external interface, used by javascript to
		// pass in a JSON string
		//
		public function load( s:String ):void {
			this.parse_json( s );
		}

		//
		// JSON is loaded from an external URL
		//
		private function xmlLoaded(event:Event):void {
			var loader:URLLoader = URLLoader(event.target);
			this.parse_json( loader.data );
		}
		
		//
		// we have data! parse it and make the chart
		//
		private function parse_json( json_string:String ):void {
			
			// tr.ace(json_string);
			
			var ok:Boolean = false;
			
			try {
				var json:Object = JSON.deserialize( json_string );
				ok = true;
			}
			catch (e:Error) {
				// remove the 'loading data...' msg:
				
  			while (this.numChildren > 0)
  				this.removeChildAt(0);
				this.addChild( new JsonErrorMsg( json_string as String, e ) );
			}
			
			//
			// don't catch these errors:
			//
			if( ok )
			{
				// remove 'loading data...' msg:
  			while (this.numChildren > 0)
  				this.removeChildAt(0);
				this.build_chart( json );
				
				// force this to be garbage collected
				json = null;
			}
			
			json_string = '';
		}
		
		private function build_chart( json:Object ):void {
			
			CONFIG::debug { tr.ace('----'); }
			CONFIG::debug { tr.ace(JSON.serialize(json)); }
			CONFIG::debug { tr.ace('----'); }
			if ( this.obs != null )
				this.die();
			
			// init singletons:
			NumberFormat.getInstance( json );
			NumberFormat.getInstanceY2( json );

			this.tooltip	= new Tooltip( json.tooltip )

			var g:Global = Global.getInstance();
			g.set_tooltip_string( this.tooltip.tip_text );
		
			//
			// these are common to both X Y charts and PIE charts:
			this.background	= new Background( json );
			this.title		= new Title( json.title );
			//
			this.addChild( this.background );
			//
			
			var is_done:Boolean = false;
			CONFIG::enable_radar {
  			if (JsonInspector.is_radar( json ) ) {

  				this.obs = Factory.MakeChart( json );
  				this.radar_axis = new RadarAxis( json.radar_axis );
  				this.keys = new Keys( this.obs );

  				this.addChild( this.radar_axis );
  				this.addChild( this.keys );
          is_done = true;
  			}			  
			}
			CONFIG::enable_pie {
			  if (JsonInspector.has_pie_chart( json )) {			    
  				// this is a PIE chart
  				this.obs = Factory.MakeChart( json );

  				// PIE charts default to FOLLOW tooltips
  				this.tooltip.set_tip_style( Tooltip.NORMAL );
  				is_done = true;
			  }
			}

      if (!is_done) {
        // Not pie and not radar.
				this.build_chart_background( json );
      }

			// these are added in the Flash Z Axis order
			this.addChild( this.title );
			for each( var set:Sprite in this.obs.sets )
				this.addChild( set );
			this.chart_overlay = new ChartOverlay(json.chart_overlay);
			this.addChild(this.chart_overlay);
			this.addChild( this.tooltip );

			this.ok = true;
			this.resize();
		}
		
		//
		// PIE charts don't have this.
		// build grid, axis, legends and key
		//
		private function build_chart_background( json:Object ):void {
			this.chart_background = new ChartBackground(json.chart_background)
			this.x_legend		= new XLegend( json.x_legend );			
			this.y_legend		= new YLegendLeft( json );
			this.y_legend_2		= new YLegendRight( json );
			this.x_axis			= new XAxis( json.x_axis );
			this.y_axis			= new YAxisLeft( json );
			this.y_axis_right	= new YAxisRight( json );
			
			//
			// This reads all the 'elements' of the chart
			// e.g. bars and lines, then creates them as sprites
			//
			this.obs			= Factory.MakeChart( json );
			//
			
			// the X Axis labels *may* require info from
			// this.obs
			this.x_labels		= new XAxisLabels( json );
			
			if( !this.x_axis.range_set() )
			{
				//
				// the user has not told us how long the X axis
				// is, so we figure it out:
				//
				if( this.x_labels.need_labels ) {
					//
					// No X Axis labels set:
					//
					
					CONFIG::debug { tr.ace( 'max x'); }
					CONFIG::debug { tr.ace( this.obs.get_max_x() ); }
					this.x_axis.set_range( this.obs.get_min_x(), this.obs.get_max_x() );
					this.x_labels.auto_label( this.x_axis.get_range(), this.x_axis.get_steps() );
				}
				else
				{
					//
					// X Axis labels used, even so, make the chart
					// big enough to show all values
					//
					this.x_axis.set_range(
						this.obs.get_min_x(),
						Math.max( this.x_labels.count(), this.obs.get_max_x() ) );
				}
			}
			else
			{
				//range set, but no labels...
				this.x_labels.auto_label( this.x_axis.get_range(), this.x_axis.get_steps() );
			}
			
			// access all our globals through this:
			var g:Global = Global.getInstance();
			// this is needed by all the elements tooltip
			g.x_labels = this.x_labels;
			g.x_legend = this.x_legend;

			//  can pick up X Axis labels for the
			// tooltips
			this.obs.tooltip_replace_labels( this.x_labels );
			//
			//
			//
			
			this.keys = new Keys( this.obs );
			
			this.addChild(this.chart_background);
			this.addChild( this.x_legend );
			this.addChild( this.y_legend );
			this.addChild( this.y_legend_2 );
			this.addChild( this.x_labels );
			this.addChild( this.y_axis );
			this.addChild( this.y_axis_right );
			this.addChild( this.x_axis );
			this.addChild( this.keys );
		}
		
		/**
		 * Remove all our referenced objects
		 */
		private function die():void {
			this.obs.die();
			this.obs = null;
			
			if ( this.tooltip != null ) this.tooltip.die();
			
			if ( this.x_legend != null )	this.x_legend.die();
			if ( this.y_legend != null )	this.y_legend.die();
			if ( this.y_legend_2 != null )	this.y_legend_2.die();
			if ( this.x_labels != null )	this.x_labels.die();
			if ( this.y_axis != null )		this.y_axis.die();
			if ( this.y_axis_right != null ) this.y_axis_right.die();
			if ( this.x_axis != null )		this.x_axis.die();
			if ( this.keys != null )		this.keys.die();
			if ( this.title != null )		this.title.die();
			CONFIG::enable_radar {
			  if (this.radar_axis != null )	this.radar_axis.die();
		  }
			if ( this.background != null )	this.background.die();
			
			this.tooltip = null;
			this.x_legend = null;
			this.y_legend = null;
			this.y_legend_2 = null;
			this.x_labels = null;
			this.y_axis = null;
			this.y_axis_right = null;
			this.x_axis = null;
			this.keys = null;
			this.title = null;
			CONFIG::enable_radar {
			  this.radar_axis = null;
			}
			this.background = null;
			
			while ( this.numChildren > 0 )
				this.removeChildAt(0);
		
			if ( this.hasEventListener(MouseEvent.MOUSE_MOVE))
				this.removeEventListener(MouseEvent.MOUSE_MOVE, this.mouseMove);
			
			// do not force a garbage collection, it is not supported:
			// http://stackoverflow.com/questions/192373/force-garbage-collection-in-as3
		
		}
		
		CONFIG::enable_context_menu
		private function build_right_click_menu(): void {
			var cm:ContextMenu = new ContextMenu();
			cm.addEventListener(ContextMenuEvent.MENU_SELECT, onContextMenuHandler);
			cm.hideBuiltInItems();

			// OFC CREDITS
			var fs:ContextMenuItem = new ContextMenuItem("Charts by Open Flash Chart 2" );
			fs.addEventListener(
				ContextMenuEvent.MENU_ITEM_SELECT,
				function doSomething(e:ContextMenuEvent):void {
					var url:String = "http://teethgrinder.co.uk/open-flash-chart-2/";
					var request:URLRequest = new URLRequest(url);
					flash.net.navigateToURL(request, '_blank');
				});
			cm.customItems.push( fs );
			
			CONFIG::enable_save_image {
  			var save_image_message:String = ( this.chart_parameters['save_image_message'] ) ? this.chart_parameters['save_image_message'] : 'Save Image Locally';

  			var dl:ContextMenuItem = new ContextMenuItem(save_image_message);
  			dl.addEventListener(ContextMenuEvent.MENU_ITEM_SELECT, this.saveImage);
  			cm.customItems.push( dl );			  
			}
			
			this.contextMenu = cm;
		}
		
		public function format_y_axis_label( val:Number ): String {
//			if( this._y_format != undefined )
//			{
//				var tmp:String = _root._y_format.replace('#val#',_root.format(val));
//				tmp = tmp.replace('#val:time#',_root.formatTime(val));
//				tmp = tmp.replace('#val:none#',String(val));
//				tmp = tmp.replace('#val:number#', NumberUtils.formatNumber (Number(val)));
//				return tmp;
//			}
//			else
				return NumberUtils.format(val,2,true,true,false);
		}


	}
	
}
