/** Configures the Lantern network proxy on all interfaces.

 By Leah X Schmidt
 Copyright 2013, Brave New Software

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.

 */
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTask.h>
#import <Foundation/NSData.h>
#import <Foundation/NSArray.h>
#import <Foundation/Foundation.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSAutoreleasePool.h>

NSString* networkSetupPath = @"/usr/sbin/networksetup";

void runNetworkSetup(NSString *command, NSString *arg1, NSString *arg2) {

    NSTask *task;
    task = [[NSTask alloc] init];
    [task setLaunchPath: networkSetupPath];

    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];

    NSArray *arguments;
    arguments = [NSArray arrayWithObjects: command, arg1, arg2, nil];
    [task setArguments: arguments];

    [task launch];

    //ignore output
    [[pipe fileHandleForReading] readDataToEndOfFile];

}

void configureNetworkServices(NSString *onOff, NSString *url) {

    NSTask *task;
    task = [[NSTask alloc] init];
    [task setLaunchPath: networkSetupPath];

    NSArray *arguments;
    arguments = [NSArray arrayWithObjects: @"-listallnetworkservices", nil];
    [task setArguments: arguments];

    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];

    NSFileHandle *file;
    file = [pipe fileHandleForReading];

    [task launch];

    NSData *data;
    data = [file readDataToEndOfFile];

    NSString *string;
    string = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];

    NSArray *lines = [string componentsSeparatedByString:@"\n"];
    int line = 0;
    for (NSString *s in lines) {
        line += 1;
        if (line == 1)
            //skip first line
            continue;
        if ([s length] == 0)
            continue;
        runNetworkSetup(@"-setautoproxyurl", s, url);
        runNetworkSetup(@"-setautoproxystate", s, onOff);
    }

}

int main() {
    NSArray *args = [[NSProcessInfo processInfo] arguments];

    configureNetworkServices([args objectAtIndex:1],
                             [args objectAtIndex:2]);

    return 0;
}
