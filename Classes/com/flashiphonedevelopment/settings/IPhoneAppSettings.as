package com.flashiphonedevelopment.settings
{
	import flash.desktop.NativeApplication;
	import flash.errors.IOError;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;
	
	public class IPhoneAppSettings
	{
		private var refCount:int;
		private var offsetCount:int;
		private var objectCount:int;
		private var topLevelOffset:int;
		
		private var objectTable:Array;
		private var keys:Array;
		private var values:Array;
		
		private var __settings:Dictionary;
		private var __file:File;
		private var __path:String;
		
		public static function getInstance():IPhoneAppSettings
		{
			return( new IPhoneAppSettings( new SingletonEnforcer() ) );	
		}
		
		
		public function IPhoneAppSettings( enforcer:SingletonEnforcer )
		{
			__path = "Library/Preferences/" + NativeApplication.nativeApplication.applicationID + ".plist";
			__file = File.userDirectory.resolvePath( __path );
			if( __file.exists )
			{
				readBinary( __file );	
			}
		}
		
		public function objectForKey( key:String ):Object
		{
			return( __settings[ key ] );
		}
		
		public function boolForKey( key:String ):Boolean
		{
			return( objectForKey( key ) as Boolean );
		}
		
		public function stringForKey( key:String ):String
		{
			return( objectForKey( key ) as String );
		}
		
		public function numberForKey( key:String ):Number
		{
			return( objectForKey( key ) as Number );
		}

		public function intForKey( key:String ):int
		{
			return( objectForKey( key ) as int );
		}
		
		public function setBoolForKey( key:String, value:Boolean ):void
		{
			__settings[ key ] = value;
			save();
		}
		
		public function setStringForKey( key:String, value:String ):void
		{
			__settings[ key ] = value;
			save();
		}
		
		public function setNumberForKey( key:String, value:Number ):void
		{
			__settings[ key ] = value;
			save();
		}
		
		public function setIntForKey( key:String, value:int ):void
		{
			__settings[ key ] = value;
			save();
		}
		
		
		private function readBinary( file:File ):void
		{
			var fd:FileStream = new FileStream();
			fd.open( file, FileMode.READ );
			
			var ba:ByteArray = new ByteArray();
			fd.readBytes( ba );
			fd.close();
			
			ba.position = 0;
			
			var bpli:int = ba.readInt();
			var st00:int = ba.readInt();
			if (bpli != 0x62706c69 || st00 != 0x73743030) {
				throw new IOError("parseHeader: File does not start with 'bplist00' magic.");
			}
			
			ba.position = ba.length - 32;
			
			offsetCount = readLong( ba );
			//  count of object refs in arrays and dicts
			refCount = readLong( ba );
			//  count of offsets in offset table (also is number of objects)
			objectCount = readLong( ba );
			//  element # in offset table which is top level object
			topLevelOffset = readLong( ba );
			
			
			var buf:ByteArray = new ByteArray();
			ba.position = 8;
			ba.readBytes( buf, 0, topLevelOffset - 8 );
			
			objectTable = [null];
			buf.position = 0;
			parseObjectTable( buf );
			
			__settings = new Dictionary();
			
			for( var i:int = 0; i<keys.length; i++ )
			{
				__settings[ String( objectTable[ keys[ i ] ] ) ] = objectTable[ values[ i ] ];
			}
		}
		
		private function parseObjectTable( ba:ByteArray ):void
		{
			var marker:int;
			while( ba.bytesAvailable > 0 ) 
			{
				marker = read( ba );
				var type:int = (marker & 0xf0) >> 4;
				var count:int;
				switch ( type ) 
				{
					case 0:
						parsePrimitive( marker & 0xf );
						break;
					case 1:
						count = 1 << (marker & 0xf);
						parseInt(ba, count);
						break;
					case 2:
						count = 1 << (marker & 0xf);
						parseReal(ba, count);
						break;
					case 3:
						throw new IOError( "Date currently not supported" );
						break;
					case 4:
						count = marker & 0xf;
						if (count == 15) 
						{
							count = readCount(ba);
						}
						parseData(ba, count);
						break;
					case 5:
						count = marker & 0xf;
						if (count == 15) 
						{
							count = readCount(ba);
						}
						parseAsciiString(ba, count);
						break;
					case 6:
						throw new IOError( "Unicode strings currently not supported" );
						break;
					case 7:
					case 8:
					case 9:
						throw new IOError( "Illegal marker " + marker );
						break;
					case 10:
						throw new IOError( "Arrays currently not supported" );
						break;
					case 11:
					case 12:
						throw new IOError( "Illegal marker " + marker );
						break;
					case 13:
						count = marker & 0xf;
						
						if (count == 15) 
						{
							count = readCount(ba);
						}
						
						if (refCount > 256) 
						{
							parseShortDict(ba, count);
						} 
						else 
						{
							parseByteDict(ba, count);
						}
						break;
					case 14:
					case 15:
						throw new IOError( "Illegal marker " + marker );
						break;
				}
			}
		}
		
		/**
		 * null	0000 0000
		 * bool	0000 1000			// false
		 * bool	0000 1001			// true
		 * fill	0000 1111			// fill byte
		 */
		private function parsePrimitive( primitive:int ):void
		{
			switch (primitive) {
				case 0:
					objectTable.push(null);
					break;
				case 8:
					objectTable.push(false);
					break;
				case 9:
					objectTable.push(true);
					break;
				case 15:
					// fill byte: don't add to object table
					break;
				default :
					throw new IOError("parsePrimitive: illegal primitive "+ primitive );
			}
		}
		
		private function read( ba:ByteArray ):int
		{
			var str:String = ba.readUTFBytes( 1 );
			return( str.charCodeAt() );
		}
		
		/**
		 * real	0010 nnnn	...		// # of bytes is 2^nnnn, big-endian bytes
		 */
		private function parseReal( ba:ByteArray, count:int ):void
		{
			switch (count) 
			{
				case 4 :
					objectTable.push( ba.readFloat() );
					break;
				case 8 :
					objectTable.push( ba.readDouble() );
					break;
				default :
					throw new IOError("parseReal: unsupported byte count:"+count);
			}
		}
		
		private function parseInt(ba:ByteArray, count:int ):void
		{
			if (count > 8) 
			{
				throw new IOError("parseInt: unsupported byte count:"+count);
			}
			
			var value:int = 0;
			for (var i:int=0; i < count; i++) 
			{
				var b:int = read( ba );
				if (b == -1) 
				{
					throw new IOError("parseInt: Illegal EOF in value");
				}
				value = (value << 8) | b;
			}
			objectTable.push( value );
		}
		
		private function parseData(ba:ByteArray, count:int ):void
		{
			var buf:ByteArray = new ByteArray();
			ba.readBytes( buf, 0, count );
			
			objectTable.push(buf);
		}
		
		private function readCount( ba:ByteArray ):int
		{
			var marker:int = read( ba );
			if (marker == -1) 
			{
				throw new IOError("variableLengthInt: Illegal EOF in marker");
			}
			
			if(((marker & 0xf0) >> 4) != 1) 
			{
				throw new IOError("variableLengthInt: Illegal marker "+ marker );
			}
			
			var count:int = 1 << (marker & 0xf);
			var value:int = 0;
			for (var i:int=0; i < count; i++) {
				var b:int = read( ba );
				if (b == -1) {
					throw new IOError("variableLengthInt: Illegal EOF in value");
				}
				value = (value << 8) | b;
			}
			return value;
		}
		
		private function parseByteDict( ba:ByteArray, count:int ) :void
		{
			keys = [];
			values = [];
			
			var i:int;
			
			for ( i=0; i < count; i++) 
			{
				keys[i] = ba.readByte() & 0xff;
			}
			
			for ( i=0; i < count; i++) 
			{
				values[i] = ba.readByte() & 0xff;
			}
			
			//objectTable.p(dict);
		}
		
		private function parseShortDict(ba:ByteArray, count:int ):void
		{
			keys = [];
			values = [];
			
			var i:int;
			
			for ( i=0; i < count; i++) {
				keys[i] = ba.readShort() & 0xffff;
			}
			for ( i=0; i < count; i++) {
				values[i] = ba.readShort() & 0xffff;
			}
			
			//objectTable.add(dict);
		}
		
		private function parseAsciiString( ba:ByteArray, count:int ):void
		{
			var str:String = ba.readUTFBytes( count );
			objectTable.push(str);
		}
		
		private function readLong( ba:ByteArray ):int
		{
			var ret:int = 0;
			for( var i:int = 0; i < 8; i++ )
			{
				ret <<= 8;
				ret |= read( ba );
			}
			
			return( ret );
		}
		
		private function getNumObjects():int
		{
			var count:int = 1;
			for( var prop:String in __settings )
			{
				count += 2;
			}
			
			return( count );	
		}
		
		
		private function byteCount( count:int ):int 
		{
			var mask:int = ~0;
			var size:int = 0;
			
			// Find something big enough to hold 'count'
			while (count & mask) 
			{
				size++;
				mask = mask << 8;
			}
			
			// Ensure that 'count' is a power of 2
			// For sizes bigger than 8, just use the required count
			while ((size != 1 && size != 2 && size != 4 && size != 8) && size <= 8) 
			{
				size++;
			}
			
			return size;
		}
		
		
		
		
		///writing
		
		private function save():void
		{
			var ba:ByteArray = new ByteArray();
			ba.writeUTFBytes( "bplist00" );
			
			var cnt:int = getNumObjects();
			var offsets:Array = [];
			var marker:int;
			var i:int;
			var key:String;
			var value:Object;
			
			var trailer:CFBinaryPlistTrailer = new CFBinaryPlistTrailer();
			trailer.numObjects = cnt;
			trailer.topObjects = 0;
			trailer.objectRefSize = byteCount( cnt );
			
			offsets.push( ba.position );
			
			//write the settings dictionary
			var dictlength:int = (cnt-1)/2;
			marker = 0xD0 | (dictlength < 15 ? dictlength : 0xf);
			ba.writeByte(marker);
			if (15 <= dictlength) 
			{
				appendInt( ba, dictlength);
			}
			
			//write the positions
			for( i = 0; i<cnt-1; i++ )
			{
				ba.writeByte( i + 1 );	
			}
			
			var keys:Array = [];
			var values:Array = [];
			
			for( key in __settings )
			{
				keys.push( key );
				values.push( __settings[ key ] );	
			}
			
			for( i = 0; i<keys.length; i++ )
			{
				offsets.push( ba.position );
				key = keys[ i ] as String;
				writeString( ba, key );	
			}
			
			for( i = 0; i<values.length; i++ )
			{
				offsets.push( ba.position );
				value = values[ i ];
				if( value is String )
				{
					writeString( ba, value as String );	
				}	
				else if( value is Number )
				{
					var numString:String = Number( value ).toString();
					var hasdecimal:Boolean = ( numString.indexOf( "." )	!= -1 );
					if( int( value ) == value && !hasdecimal && value is int )
					{
						//write int
						writeInt( ba, int( value ) );
					}
					else
					{
						//write a double
						writeDouble( ba, Number( value ) );
					}
				}
				else if( value is Boolean )
				{
					writeBoolean( ba, value as Boolean );	
				}
			}
			
			var length_so_far:int = ba.length;
			trailer.offsetTableOffset = length_so_far;
			trailer.offsetIntSize = byteCount( length_so_far );
			
			for( i = 0; i<offsets.length; i++ )
			{
				var offset:int = offsets[ i ] as int;
				ba.writeByte( offset );	
			}
			
			writeTrailer( ba, trailer );
			
			var file:File = File.userDirectory.resolvePath( __path );
			
			var stream:FileStream = new FileStream();
			stream.open(file, FileMode.WRITE );
			stream.writeBytes( ba );
			stream.close();
		}
		
		private function writeBoolean( ba:ByteArray, val:Boolean ):void
		{
			var marker:int = ( val ) ? 0x09 : 0x08;
			ba.writeByte( marker );
		}
		
		private function writeDouble( ba:ByteArray, val:Number ):void
		{
			var marker:int = 0x20 | 3;
			ba.writeByte( marker );
			ba.writeDouble( val );
		}
		
		private function writeFloat( ba:ByteArray, val:Number ):void
		{
			var marker:int = 0x20 | 2;
			ba.writeByte( marker );
			ba.writeFloat( val );
		}
		
		private function writeInt( ba:ByteArray, val:int ):void
		{
			var marker:int = 0x10 | 4;
			ba.writeByte( marker );
			ba.writeInt( val );	
		}
		
		
		private function writeString( ba:ByteArray, str:String ):void
		{
			var needed:int = str.length;
			var marker:int = (0x50 | (needed < 15 ? needed : 0xf));
			
			ba.writeByte( marker );
			
			if( 15 <= needed )
			{
				appendInt( ba, needed );
			}
			ba.writeUTFBytes( str );
		}
		
		private function writeTrailer( ba:ByteArray, trailer:CFBinaryPlistTrailer ):void
		{
			var i:int;
			for( i = 0; i<trailer.unused.length; i++ )
			{
				var byte:int = trailer.unused[ i ] as int;
				ba.writeByte( byte );	
			}
			
			ba.writeByte( trailer.offsetIntSize );
			ba.writeByte( trailer.objectRefSize );
			
			for( i = 0; i<7; i++ )
			{
				ba.writeByte( 0 );	
			}
			
			ba.writeByte( trailer.numObjects );
			
			for( i = 0; i<7; i++ )
			{
				ba.writeByte( 0 );	
			}
			ba.writeByte( trailer.topObjects );
			
			for( i = 0; i<7; i++ )
			{
				ba.writeByte( 0 );	
			}
			ba.writeByte( trailer.offsetTableOffset );
		}
		
		private function appendInt( ba:ByteArray, bigint:int ):void
		{
			
			var marker:int;
			var bytes:int;
			var nbytes:int;
			if(bigint <= 0xff ) 
			{
				nbytes = 1;
				marker = 0x10 | 0;
			} 
			else if (bigint <= 0xffff) 
			{
				nbytes = 2;
				marker = 0x10 | 1;
			} 
			else if (bigint <= 0xffffffff) 
			{
				nbytes = 4;
				marker = 0x10 | 2;
			} 
			else 
			{
				nbytes = 8;
				marker = 0x10 | 3;
			}
			
			//write marker to the stream
			//write bigint to the stream
			ba.writeByte( marker );
			ba.writeByte( bigint );
			
		}
	}
}


internal class CFBinaryPlistHeader
{	
	
	public function CFBinaryPlistHeader()
	{
	}
}

internal class CFBinaryPlistTrailer
{
	
	public var unused:Array;
	public var offsetIntSize:int;
	public var objectRefSize:int;
	public var numObjects:int;
	public var topObjects:int;
	public var offsetTableOffset:int;
	
	public function CFBinaryPlistTrailer()
	{
		unused = [ 0,0,0,0,0,0 ];
	}
}

internal class CFTypes
{
	public static const kCFBinaryPlistMarkerNull:uint = 0x00;
	public static const kCFBinaryPlistMarkerFalse:uint = 0x08;
	public static const kCFBinaryPlistMarkerTrue:uint = 0x09;
	public static const kCFBinaryPlistMarkerFill:uint = 0x0F;
	public static const kCFBinaryPlistMarkerInt:uint = 0x10;
	public static const kCFBinaryPlistMarkerReal:uint = 0x20;
	public static const kCFBinaryPlistMarkerDate:uint = 0x33;
	public static const kCFBinaryPlistMarkerData:uint = 0x40;
	public static const kCFBinaryPlistMarkerASCIIString:uint = 0x50;
	public static const kCFBinaryPlistMarkerUnicode16String:uint = 0x60;
	public static const kCFBinaryPlistMarkerUID:uint = 0x80;
	public static const kCFBinaryPlistMarkerArray:uint = 0xA0;
	public static const kCFBinaryPlistMarkerSet:uint = 0xC0;
	public static const kCFBinaryPlistMarkerDict:uint = 0xD0;	
}

internal class SingletonEnforcer
{
	public function SingletonEnforcer(){};
}





