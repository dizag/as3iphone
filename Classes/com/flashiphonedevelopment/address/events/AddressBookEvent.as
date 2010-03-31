package com.flashiphonedevelopment.address.events 
{
	import flash.events.Event;

	/**
	 * @author julian
	 */
	public class AddressBookEvent extends Event 
	{
		
		public static const CONTACT_DETAILS:String = "contactdetails";
		public static const CONTACT_LIST:String = "contactlist";
		
		private var __data:Array;
		
		public function get data():Array
		{
			return( __data );	
		}
		
		public function AddressBookEvent( type:String, data:Array )
		{
			__data = data;
			super(type);
		}
	}
}
