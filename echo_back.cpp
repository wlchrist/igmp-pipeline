//#include <string.h>
//#include <sys/socket.h>
//#include <netinet/in.h>

void send_string(int sock, const char* msg, struct sockaddr_in* addr, int addrLen) {
  sendto(sock, msg, strlen(msg), 0, (struct sockaddr*)addr, addrLen);
}

//example call: 
// send_string(sock, "Hello from device!", &addr, addrLen);
