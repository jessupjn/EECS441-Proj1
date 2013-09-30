//
//  iPadChat.m
//  EECS441-1
//
//  Created by Jackson on 9/12/13.
//
//

#import "iPadChat.h"
#import "eventKind.pb.h"


@interface iPadChat () <UITableViewDelegate, UITableViewDataSource, UITextViewDelegate, CollabrifyClientDataSource, CollabrifyClientDelegate>

@property (nonatomic) chalkBoard *theEvent;

@end

@implementation iPadChat

@synthesize client;
@synthesize theEvent;
@synthesize undoManager;


// UPDATES THE TEXT IF THE CLIENT DETECTS AN EVENT
- (void)client:(CollabrifyClient *)client receivedEventWithOrderID:(int64_t)orderID submissionRegistrationID:(int32_t)submissionRegistationID eventType:(NSString *)eventType data:(NSData *)data
{
  dispatch_async(dispatch_get_main_queue(),^{
    
    // parses apart the event that was receiverd
    chalkBoard *newEvent = new chalkBoard;
    newEvent->ParseFromArray([data bytes], [data length]);
    std::string string = newEvent->changes();
    NSString *objcString = [NSString stringWithCString:string.c_str() encoding:[NSString defaultCStringEncoding]];
    int loc = newEvent->where();
    
    NSLog(@"%i %i %@", loc, submissionRegistationID, objcString);
    
    if ( ![list count] || ![list containsObject:[NSString stringWithFormat:@"%i", submissionRegistationID]] ) {
      
      // if the other users added a letter
      if ([eventType isEqualToString:@"update"]){
        if (loc > [noteData.text length]){
          [noteData setText:[NSString stringWithFormat:@"%@%@", noteData.text, objcString]];
        }
        else{
          NSString *firstHalf = [noteData.text substringToIndex:loc];
          NSString *secondHalf = [noteData.text substringFromIndex:loc];
          [noteData setText:[NSString stringWithFormat:@"%@%@%@", firstHalf, objcString, secondHalf]];
        }
      }
      // if the other users pressed undo
      else if ( [eventType isEqualToString:@"undo"] ){
        NSLog(@"He undid it!");
        NSLog(@"%@", objcString);
        [noteData setText:[NSString stringWithFormat:@"%@", objcString]];
      }
      // if the other users pressed redo
      else if ( [eventType isEqualToString:@"redo"] ){
        NSLog(@"He redid it!");
        NSLog(@"%@", objcString);
        [noteData setText:[NSString stringWithFormat:@"%@", objcString]];
      }
      // if the other users pressed backspace
      else if ( [eventType isEqualToString:@"delete"] ){
        NSLog(@"He backspaced! it!");
        NSRange range = NSMakeRange(loc+1, 1);
        if ( [noteData.text length] > loc ){
          
          // if the delete call is valid
          [noteData setText:[noteData.text stringByReplacingCharactersInRange:range withString:@""]];

        }
        else{

          // if they are out of sync and try to delete and we catch it... they will resync
          // to have the same text.
          addedString = [NSMutableString stringWithFormat:@"%@", noteData.text];
          theEvent->set_changes( [addedString UTF8String] );
          std::string dataData = theEvent->SerializeAsString();
          NSData *data = [NSData dataWithBytes:dataData.c_str() length:dataData.size()];
          int eventId = [self broadcastRedo:data];
          [list addObject:[NSString stringWithFormat:@"%i", eventId]];

        }
      }
    }
    else {
      NSLog(@"Detected your event");
    }
    [noteData setScrollEnabled:YES];
    
  });
}


//    TableView (populated with users)
//------------------------------------------------------
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return [currentUsers count];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
  if (cell == nil) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault  reuseIdentifier:@"cell"];
  }
  
  // Set up the cell...
  [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
  [[cell textLabel] setText: [currentUsers[indexPath.row] displayName]];
  [[cell textLabel] setTextAlignment:NSTextAlignmentCenter];
  return cell;
}
-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section{
  return 0.0;
}



- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {
    // Custom initialization
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
	// Do any additional setup after loading the view.
  
  [iPadUsersBar.layer setBorderWidth:1];
  [noteData.layer setBorderWidth:1];
  
  [noteData setDelegate:self];
  
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notepadSizeUp:) name:UIKeyboardWillHideNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notepadSizeDown:) name:UIKeyboardDidShowNotification object:nil];
  [client setDelegate:self], [client setDataSource:self];
  
  undoManager = [noteData undoManager];
  
  userList = [[UITableView alloc] initWithFrame:CGRectMake(DEVICEWIDTH-225, 138, 225, 886)];
  [userList.layer setBorderWidth:1];
  [userList setDataSource:self], [userList setDelegate:self];
  [self.view addSubview:userList];
  
  addedString = [[NSMutableString alloc] init];
  keepCount = formerSize = 0;
  
  participantsTimer = [NSTimer scheduledTimerWithTimeInterval:0.25
                                                       target:self
                                                     selector:@selector(onTheClock)
                                                     userInfo:nil
                                                      repeats:YES];
  theEvent = new chalkBoard;
  list = [[NSMutableArray alloc] init];
}

-(void)viewWillAppear:(BOOL)animated{
    
  [[self navigationItem] setPrompt:[NSString stringWithFormat:@"Session ID: %lli", [client currentSessionID]]];
  [self buildButtons];
  [self reloadTable];
  UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                                 initWithTarget:self
                                 action:@selector(doneButton)];
  [[self view] addGestureRecognizer:tap];
  
  [noteData.undoManager setGroupsByEvent:NO];
  [noteData.undoManager beginUndoGrouping];
  didUndo = didRedo = FALSE;
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

// when view is going to disappear.
-(void) viewWillDisappear:(BOOL)animated{
  [participantsTimer invalidate];
  [client leaveAndDeleteSession:YES completionHandler:^(BOOL success, CollabrifyError *error) {
    if(success){
      NSLog(@"Was it a success??     %hhd", success);
    }
    else NSLog(@"ERROR: %@", error);
  }];
}

// function called by the timer
- (void) onTheClock{
  
  if ( keepCount++ == 12 ) [self reloadTable], keepCount=0;
}

// loads names into the table of participants and sets bar title.
- (void) reloadTable{  
    currentUsers = [client currentSessionParticipants];
    numUsers = [client currentSessionParticipantCount];
  
    if (numUsers == 1)
      iPadUsersTitle = [[NSString alloc] initWithString:[NSString stringWithFormat:@"%d User", numUsers]];
    else
      iPadUsersTitle = [[NSString alloc] initWithString:[NSString stringWithFormat:@"%d Users", numUsers]];
    [iPadBar setTitle:iPadUsersTitle];
    [userList reloadData];

}

// --------------------------------------------------------------- //
// -                  KEYBOARD MOVEMENTS/LOGISTICS               - //
// --------------------------------------------------------------- //
-(BOOL)textViewShouldBeginEditing:(UITextView *)textView {
  textView.inputAccessoryView = keyboardbuttons;
  return YES;
}
- (void)buildButtons{
  keyboardbuttons = [[UIToolbar alloc] init];
  [keyboardbuttons setBarStyle:UIBarStyleDefault];
  [keyboardbuttons sizeToFit];
  
  keyboardbuttons.frame = CGRectMake(0, DEVICEHEIGHT-44, DEVICEWIDTH, 44);
  
  //Use this to put space in between your toolbox buttons
  UIBarButtonItem *undoItem = [[UIBarButtonItem alloc] initWithTitle:@"Undo"
                                                               style:UIBarButtonItemStyleBordered
                                                              target:self
                                                              action:@selector(undoButton)];
  UIBarButtonItem *flexItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                            target:nil
                                                                            action:nil];
  UIBarButtonItem *doneItem = [[UIBarButtonItem alloc] initWithTitle:@"Done"
                                                               style:UIBarButtonItemStyleDone
                                                              target:self
                                                              action:@selector(doneButton)];
  UIBarButtonItem *flexItem2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                             target:nil
                                                                             action:nil];
  UIBarButtonItem *redoItem = [[UIBarButtonItem alloc] initWithTitle:@"Redo"
                                                               style:UIBarButtonItemStyleBordered
                                                              target:self
                                                              action:@selector(redoButton)];
  
  NSArray *items = [NSArray arrayWithObjects:undoItem, flexItem, doneItem, flexItem2, redoItem, nil];
  [keyboardbuttons setItems:items animated:YES];
}
// undo button
-(void)undoButton{
  if( [noteData.undoManager canUndo] ) {
    NSData *data = [@"undo" dataUsingEncoding:NSUTF8StringEncoding];
    int eventId = [client broadcast:data eventType:@"undo"];
    [list addObject:[NSString stringWithFormat:@"%i", eventId]];
    
    didUndo = TRUE;
    if ( didUndo ){
      [noteData.undoManager endUndoGrouping];
      [noteData.undoManager undoNestedGroup];
      [noteData.undoManager undoNestedGroup];
      [noteData.undoManager beginUndoGrouping];
    }
    else {
      [noteData.undoManager endUndoGrouping];
      [noteData.undoManager undoNestedGroup];
      [noteData.undoManager beginUndoGrouping];
    }
  }
  else NSLog(@"CANT UNDO");
}
// done button
-(void)doneButton{
  [noteData resignFirstResponder];
}
// redo button
-(void)redoButton{
  NSData *data = [@"redo" dataUsingEncoding:NSUTF8StringEncoding];
  int eventId = [client broadcast:data eventType:@"redo"];
  [list addObject:[NSString stringWithFormat:@"%i", eventId]];
  
  if( [noteData.undoManager canRedo] && ![noteData.undoManager isUndoing] ){
    
    didRedo = TRUE;
    [noteData.undoManager redo];
    if ([noteData.undoManager canRedo]){
      [noteData.undoManager endUndoGrouping];
      [noteData.undoManager beginUndoGrouping];
      [noteData.undoManager redo];
    }
  }
  else NSLog(@"CANT REDO");
}
// shrinking the boxes when the keyboard comes up.
- (void)notepadSizeDown:(NSNotification*)notification{
  int keyboardHeight = [[[notification userInfo] valueForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size.height;
  [noteData setFrame:CGRectMake(0, 0, noteData.frame.size.width, noteData.frame.size.height - keyboardHeight)];
  [userList setFrame:CGRectMake(DEVICEWIDTH-225, 138, userList.frame.size.width, userList.frame.size.height - keyboardHeight)];
}
// re-expanding the boxes when the keyboard will go down
- (void)notepadSizeUp:(NSNotification*)notification{
  int keyboardHeight = [[[notification userInfo] valueForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size.height;
  [noteData setFrame:CGRectMake(0, 0, noteData.frame.size.width, noteData.frame.size.height + keyboardHeight)];
  [userList setFrame:CGRectMake(DEVICEWIDTH-225, 138, userList.frame.size.width, userList.frame.size.height + keyboardHeight)];
}
// --------------------------------------------------------------- //
// --------------------------------------------------------------- //




// --------------------------------------------------------------- //
// -                    KEEP TRACK OF CHANGES                    - //
// --------------------------------------------------------------- //
-(void) textViewDidChange:(UITextView *)textView{
  
  if ( [noteData.text length]%10 == 0 )
    [noteData.undoManager endUndoGrouping], [noteData.undoManager beginUndoGrouping];
  
  
  // current position of the cursor
  NSUInteger cursorPosition = textView.selectedRange.location;
  // Defines the start position of the string to be added into the DATA!
  
  // Defines the string to be added to the text of all users
  NSData* data;
  NSRange range = NSMakeRange(cursorPosition-1, 1);
  addedString = [NSMutableString stringWithString:[noteData.text substringWithRange:range]];
  
  // delete key was pressed
  if ( formerSize > [noteData.text length] )
    addedString = [NSMutableString stringWithFormat:@"backPressed"];
  
  if (didUndo || didRedo)
    addedString = [NSMutableString stringWithFormat:@"%@", noteData.text];
  
  theEvent->set_changes( [addedString UTF8String] );
  theEvent->set_where( noteData.selectedRange.location - 1);
  
  formerSize = [noteData.text length];
  
  std::string dataData = theEvent->SerializeAsString();
  data = [NSData dataWithBytes:dataData.c_str() length:dataData.size()];
  int eventId;
  
  // if undo was pressed
  if (didUndo){
    didUndo = FALSE;
    eventId = [self broadcastUndo:data];
  }
  
  // if redo was pressed
  else if (didRedo){
    didRedo = FALSE;
    eventId = [self broadcastRedo:data];
  }
  
  //backspace key was pressed.
  else if ( [addedString isEqualToString:@"backPressed"] )
    eventId = [self broadcastDelete:data];
  
  // adding a letter to the data.
  else
    eventId = [self broadcastUpdate:data];
  
  // add to list of your events.
  [list addObject:[NSString stringWithFormat:@"%i", eventId]];
}
-(BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
  if([text isEqualToString:@". "])
    return NO;
  return YES;
}


// all the types of broadcasts that we send
-(int) broadcastUpdate:(NSData *)data {
  int eventId = [client broadcast:data eventType:@"update"];
  return eventId;
}
-(int) broadcastDelete:(NSData *)data {
  int eventId = [client broadcast:data eventType:@"delete"];
  return eventId;
}
-(int) broadcastUndo:(NSData *)data {
  int eventId = [client broadcast:data eventType:@"undo"];
  return eventId;
}
-(int) broadcastRedo:(NSData *)data {
  int eventId = [client broadcast:data eventType:@"redo"];
  return eventId;
}




@end