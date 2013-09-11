//
//  joinSessioniPad.h
//  EECS441-1
//
//  Created by Jackson on 9/10/13.
//
//

#import <UIKit/UIKit.h>
#import <Collabrify/Collabrify.h>
#import "chat.h"

@interface joinSessioniPad : UIViewController{
  IBOutlet UIView *infoBackground;
  IBOutlet UITextField *sessionName;
  IBOutlet UITextField *password;
  CollabrifyClient *client;
  NSString *userName;
  
}
@property (nonatomic, retain) CollabrifyClient *client;


-(IBAction) back:(id) sender;
-(IBAction) join:(id) sender;

@end