package com.flashiphonedevelopment.address {
	import com.flashiphonedevelopment.address.events.AddressBookEvent;

	import flash.data.SQLConnection;
	import flash.data.SQLMode;
	import flash.data.SQLResult;
	import flash.data.SQLStatement;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.SQLEvent;
	import flash.filesystem.File;

	/**
	 * @author julian
	 */
	public class IPhoneAddressBook extends EventDispatcher 
	{
		private var __connection:SQLConnection;
		private var __contact:Contact;
		
		private var __addressLeft:int;
		private var __imLeft:int;
		
		public function IPhoneAddressBook()
		{
			
		}
		
		public function open():void
		{
			var file:File = new File( "/private/var/mobile/Library/AddressBook/AddressBook.sqlitedb" );
			__connection = new SQLConnection();
			__connection.addEventListener( SQLEvent.OPEN, onConnect );
			__connection.openAsync( file, SQLMode.READ );
		}

		private function onConnect( event:Event ):void
		{
			dispatchEvent( new Event( Event.OPEN ) );
		}
		
		public function getContactList():void
		{
			var statement:SQLStatement = new SQLStatement();
			statement.sqlConnection = __connection;
			
			var sql:String = "SELECT ROWID, First, Last FROM ABPerson";
			
			statement.text = sql;
			statement.itemClass = ABPerson;
			statement.addEventListener( SQLEvent.RESULT, contactListResult );
			statement.execute();	
		}

		private function contactListResult(event:SQLEvent):void 
		{
			var result:SQLResult = SQLStatement(event.target).getResult();
			dispatchEvent( new AddressBookEvent( AddressBookEvent.CONTACT_LIST, result.data) );
		}
		
		public function getContact( id:int ):void
		{
			getABPersonDetails( id );	
		}
		
		private function getABPersonDetails( id:int ):void
		{
			var statement:SQLStatement = new SQLStatement();
			statement.sqlConnection = __connection;
			
			var sql:String = "SELECT ROWID, First, Last, Middle, FirstPhonetic, MiddlePhonetic, LastPhonetic, Organization, Department, Note, Kind, Birthday, JobTitle, " + 
							"Nickname, Prefix, Suffix, CreationDate, ModificationDate, CompositeNameFallback, ExternalIdentifier, StoreID, DisplayName, FirstSortSection, " + 
							"LastSortSection, FirstSortLanguageIndex, LastSortLanguageIndex FROM ABPerson WHERE ROWID=" + id;
			
			statement.text = sql;
			statement.itemClass = Contact;
			statement.addEventListener( SQLEvent.RESULT, abpersonResult );
			statement.execute();	
		}

		private function abpersonResult(event:SQLEvent):void 
		{
			var result:SQLResult = SQLStatement(event.target).getResult();
			__contact = result.data[ 0 ] as Contact;
			
			var statement:SQLStatement = new SQLStatement();
			statement.sqlConnection = __connection;
			statement.text = "SELECT * FROM ABMultiValue WHERE record_id=" + __contact.ROWID;
			statement.itemClass = ABMultiValue;
			statement.addEventListener( SQLEvent.RESULT, ABMultiValueResult );
			statement.execute();
		}

		private function ABMultiValueResult(event:SQLEvent):void 
		{
			var result:SQLResult = SQLStatement(event.target).getResult();
			var i:int;
			var ims:Array = [];
			for( i = 0; i<result.data.length; i++ )
			{
				var item:ABMultiValue = result.data[ i ] as ABMultiValue;
				
				switch( item.property )
				{
					case 3:
						var phoneNumber:PhoneNumber = new PhoneNumber();
						phoneNumber.number = item.value;
						phoneNumber.type = item.label;
						__contact.numbers.push( phoneNumber );
						break;
					case 4:
						__contact.emails.push( item.value );
						break;
					case 5:
						var address:Address = new Address();
						address.id = item.UID;
						address.type = item.label;
						__contact.addresses.push( address );
						break;
					case 13:
						ims.push( item.UID );
						break;
					case 22:
						__contact.website = item.value;
						break;
				}
			}
			
			__addressLeft = __contact.addresses.length;
			__imLeft = ims.length;
			
			for( i=0; i<__contact.addresses.length; i++ )
			{
				var ad:Address = __contact.addresses[ i ] as Address;
				getAddress( ad.id );
			}
			
			for( i=0; i<ims.length; i++ )
			{
				getIM( int( ims[ i ] ) );	
			}
		}
		
		private function getAddress( id:int ):void
		{
			var statement:SQLStatement = new SQLStatement();
			statement.sqlConnection = __connection;
			statement.text = "SELECT * FROM ABMultiValueEntry WHERE parent_id=" + id;
			statement.itemClass = ABMultiValueEntry;
			statement.addEventListener( SQLEvent.RESULT, addressResults );
			statement.execute();
		}

		private function addressResults( event:SQLEvent ):void
		{
			__addressLeft--;
			var result:SQLResult = SQLStatement(event.target).getResult();	
			for( var i:int = 0; i<result.data.length; i++ )
			{
				var item:ABMultiValueEntry = result.data[ i ] as ABMultiValueEntry;
				var address:Address;
				
				for( var j:int = 0; j<__contact.addresses.length; j++ )
				{
					address = __contact.addresses[ j ];
					if( address.id == item.parent_id )
					{
						break;
					}		
				}
				
				switch( item.key )
				{
					case 1:
						address.street = item.value;
						break;
					case 2:
						address.state = item.value;
						break;
					case 3:
						address.city = item.value;
						break;
					case 4:
						address.country = item.value;
						break;
					case 5:
						address.zip = item.value;
						break;
				}
			}
			checkDetailComplete();
		}
		
		private function getIM( id:int ):void
		{
			var statement:SQLStatement = new SQLStatement();
			statement.sqlConnection = __connection;
			statement.text = "SELECT * FROM ABMultiValueEntry WHERE parent_id=" + id;
			statement.itemClass = ABMultiValueEntry;
			statement.addEventListener( SQLEvent.RESULT, imResults );
			statement.execute();	
		}
		
		private function imResults( event:SQLEvent ):void
		{
			__imLeft--;
			var result:SQLResult = SQLStatement(event.target).getResult();	
			for( var i:int = 0; i<result.data.length; i++ )
			{
				var item:ABMultiValueEntry = result.data[ i ] as ABMultiValueEntry;
				var im:InstantMessage = new InstantMessage();
				switch( item.key )
				{
					case 6:
						im.username = item.value;
						break;
					case 7:
						im.service = item.value;
						break;
				}
			}
			checkDetailComplete();
		}
		
		private function checkDetailComplete():void
		{
			if( __imLeft == 0 && __addressLeft == 0 )
			{
				var data:Array = [];
				data.push( __contact );
				dispatchEvent( new AddressBookEvent(AddressBookEvent.CONTACT_DETAILS, data)	);
			}
		}
	}
}
