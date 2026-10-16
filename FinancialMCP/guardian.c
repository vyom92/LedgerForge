#include <sys/event.h>
#include <sys/wait.h>
#include <sys/time.h>
#include <unistd.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>
// Runs only as an inherited-sandbox child. No registration, database, or filesystem access.
// stdin is a pipe whose only writer is the owning application. Child must not inherit it.
static volatile sig_atomic_t stopping=0;
static void stop(int sig){(void)sig;stopping=1;}
int main(int argc,char **argv){
 if(argc<3)return 64;
 pid_t owner=(pid_t)atoi(argv[1]);
 if(owner<=1 || getppid()!=owner)return 65;
 if(setpgid(0,0)<0)return 71;
 signal(SIGTERM,stop);signal(SIGINT,stop);signal(SIGHUP,stop);signal(SIGPIPE,SIG_IGN);
 int kq=kqueue(); if(kq<0)return 66;
 fcntl(kq,F_SETFD,FD_CLOEXEC);
 struct kevent ev;EV_SET(&ev,owner,EVFILT_PROC,EV_ADD|EV_ENABLE,NOTE_EXIT,0,NULL);
 if(kevent(kq,&ev,1,NULL,0,NULL)<0)return 67;
 if(getppid()!=owner)return 68;
 pid_t child=fork();if(child<0)return 69;
 if(child==0){
  signal(SIGTERM,SIG_DFL);signal(SIGINT,SIG_DFL);signal(SIGHUP,SIG_DFL);
  close(kq);close(STDIN_FILENO);int n=open("/dev/null",O_RDONLY);if(n!=STDIN_FILENO){dup2(n,STDIN_FILENO);close(n);}
  execv(argv[2],&argv[2]);_exit(70);
 }
 printf("{\"event\":\"tunnel_spawned\",\"guardian\":%d,\"owner\":%d,\"pid\":%d}\n",getpid(),owner,child);fflush(stdout);
 EV_SET(&ev,STDIN_FILENO,EVFILT_READ,EV_ADD|EV_ENABLE,0,0,NULL);kevent(kq,&ev,1,NULL,0,NULL);
 int status=0,exited=0;
 while(!stopping){
  if(waitpid(child,&status,WNOHANG)==child){exited=1;break;}
  struct timespec timeout={0,100000000};int count=kevent(kq,NULL,0,&ev,1,&timeout);
  if(count>0){if(ev.filter==EVFILT_PROC)break;if(ev.filter==EVFILT_READ){char b[16];if(read(0,b,sizeof(b))<=0)break;}}
  if(getppid()!=owner)break;
 }
 // The app owns this process group; the guardian reaps only its exact child.
 if(!exited)kill(child,SIGTERM);
 for(int i=0;i<20&&!exited;i++){if(waitpid(child,&status,WNOHANG)==child){exited=1;break;}usleep(50000);}
 if(!exited){kill(child,SIGKILL);while(waitpid(child,&status,0)<0&&errno==EINTR){}}
 printf("{\"event\":\"tunnel_reaped\",\"owner\":%d,\"pid\":%d}\n",owner,child);fflush(stdout);
 close(kq);return 0;
}
