//
//  cchud.h
//  Cyanide
//

#ifndef cchud_h
#define cchud_h

#import <stdbool.h>

bool cchud_apply_in_session(void);
bool cchud_stop_in_session(void);
void cchud_forget_remote_state(void);

#endif /* cchud_h */
