package com.flashiphonedevelopment.address 
{

	/**
	 * @author julian
	 */
	public class Contact 
	{
		public var ROWID:int;
		public var First:String;
		public var Last:String;
		public var Middle:String;
		public var FirstPhonetic:String;
		public var MiddlePhonetic:String;
		public var LastPhonetic:String;
		public var Organization:String;
		public var Department:String;
		public var Note:String;
		public var Kind:int;
		public var Birthday:String;
		public var JobTitle:String;
		public var Nickname:String;
		public var Prefix:String;
		public var Suffix:String;
		public var CreationDate:int;
		public var ModificationDate:int;
		public var CompositeNameFallback:String;
		public var ExternalIdentifier:String;
		public var StoreID:int;
		public var DisplayName:String;
		public var FirstSortSection:String;
		public var LastSortSection:String;
		public var FirstSortLanguageIndex:int;
		public var LastSortLanguageIndex:int;
		
		public var emails:Array = [];
		public var numbers:Array = [];
		public var website:String;
		public var instantMessage:Array = [];
		public var addresses:Array = [];
	}
}
