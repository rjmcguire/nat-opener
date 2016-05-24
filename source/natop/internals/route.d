﻿module natop.internals.route;

version(OSX):
import core.sys.posix.sys.socket;

extern (C) int sysctl(const int* name, int nlen, void* oldval, size_t* oldlen, void* newval, size_t newlen) @nogc nothrow;

enum PF_ROUTE = 17;
enum NET_RT_DUMP = 1;
enum CTL_NET = 4;

/*
 * Kernel resident routing tables.
 *
 * The routing tables are initialized when interface addresses
 * are set by making entries for all directly connected interfaces.
 */

/*
 * A route consists of a destination address and a reference
 * to a routing entry.  These are often held by protocols
 * in their control blocks, e.g. inpcb.
 */
struct route;
/*
 * These numbers are used by reliable protocols for determining
 * retransmission behavior and are included in the routing structure.
 */
struct rt_metrics {
	uint	rmx_locks;	/* Kernel must leave these values alone */
	uint	rmx_mtu;	/* MTU for this path */
	uint	rmx_hopcount;	/* max hops expected */
	int		rmx_expire;	/* lifetime for route, e.g. redirect */
	uint	rmx_recvpipe;	/* inbound delay-bandwidth product */
	uint	rmx_sendpipe;	/* outbound delay-bandwidth product */
	uint	rmx_ssthresh;	/* outbound gateway buffer limit */
	uint	rmx_rtt;	/* estimated round trip time */
	uint	rmx_rttvar;	/* estimated rtt variance */
	uint	rmx_pksent;	/* packets sent using this route */
	uint[4]	rmx_filler;	/* will be used for T/TCP later */
}

/*
 * rmx_rtt and rmx_rttvar are stored as microseconds;
 */
enum RTM_RTTUNIT	= 1000000;	/* units for rtt, rttvar, as units per sec */
enum {
	RTF_UP		= 0x1,		/* route usable */
		RTF_GATEWAY	= 0x2,		/* destination is a gateway */
		RTF_HOST	= 0x4,		/* host entry (net otherwise) */
		RTF_REJECT	= 0x8,		/* host or net unreachable */
		RTF_DYNAMIC	= 0x10,		/* created dynamically (by redirect) */
		RTF_MODIFIED	= 0x20,		/* modified dynamically (by redirect) */
		RTF_DONE	= 0x40,		/* message confirmed */
		RTF_DELCLONE	= 0x80,		/* delete cloned route */
		RTF_CLONING	= 0x100,	/* generate new routes on use */
		RTF_XRESOLVE	= 0x200,		/* external daemon resolves name */
		RTF_LLINFO	= 0x400,		/* generated by link layer (e.g. ARP) */
		RTF_STATIC	= 0x800,		/* manually added */
		RTF_BLACKHOLE	= 0x1000,		/* just discard pkts (during updates) */
		RTF_PROTO2	= 0x4000,		/* protocol specific routing flag */
		RTF_PROTO1	= 0x8000,		/* protocol specific routing flag */
		
		RTF_PRCLONING	= 0x10000,		/* protocol requires cloning */
		RTF_WASCLONED	= 0x20000,		/* route generated through cloning */
		RTF_PROTO3	= 0x40000,		/* protocol specific routing flag */
		/* 0x80000 unused */
		RTF_PINNED	= 0x100000,	/* future use */
		RTF_LOCAL	= 0x200000,	/* route represents a local address */
		RTF_BROADCAST	= 0x400000,	/* route represents a bcast address */
		RTF_MULTICAST	= 0x800000,	/* route represents a mcast address */
		RTF_IFSCOPE	= 0x1000000,	/* has valid interface scope */
		RTF_CONDEMNED	= 0x2000000	/* defunct; no longer modifiable */
			/* 0x4000000 and up unassigned */
}
/*
 * Routing statistics.
 */
struct	rtstat {
	short	rts_badredirect;	/* bogus redirect calls */
	short	rts_dynamic;		/* routes created by redirects */
	short	rts_newgateway;		/* routes modified by redirects */
	short	rts_unreach;		/* lookups which failed */
	short	rts_wildcard;		/* lookups satisfied by a wildcard */
}

/*
 * Structures for routing messages.
 */
struct rt_msghdr {
	ushort	rtm_msglen;		/* to skip over non-understood messages */
	ubyte	rtm_version;		/* future binary compatibility */
	ubyte	rtm_type;		/* message type */
	ushort	rtm_index;		/* index for associated ifp */
	int	rtm_flags;		/* flags, incl. kern & message, e.g. DONE */
	int	rtm_addrs;		/* bitmask identifying sockaddrs in msg */
	pid_t	rtm_pid;		/* identify sender */
	int	rtm_seq;		/* for sender to identify action */
	int	rtm_errno;		/* why failed */
	int	rtm_use;		/* from rtentry */
	uint rtm_inits;		/* which metrics we are initializing */
	rt_metrics rtm_rmx;	/* metrics themselves */
}

struct rt_msghdr2 {
	ushort	rtm_msglen;		/* to skip over non-understood messages */
	ubyte	rtm_version;		/* future binary compatibility */
	ubyte	rtm_type;		/* message type */
	ushort	rtm_index;		/* index for associated ifp */
	int	rtm_flags;		/* flags, incl. kern & message, e.g. DONE */
	int	rtm_addrs;		/* bitmask identifying sockaddrs in msg */
	int	rtm_refcnt;		/* reference count */
	int	rtm_parentflags;	/* flags of the parent route */
	int	rtm_reserved;		/* reserved field set to 0 */
	int	rtm_use;		/* from rtentry */
	uint rtm_inits;		/* which metrics we are initializing */
	rt_metrics rtm_rmx;	/* metrics themselves */
}


enum RTM_VERSION	= 5;	/* Up the ante and ignore older versions */

/*
 * Message types.
 */
enum {
	RTM_ADD		= 0x1,	/* Add Route */
	RTM_DELETE	= 0x2,	/* Delete Route */
	RTM_CHANGE	= 0x3,	/* Change Metrics or flags */
	RTM_GET		= 0x4,	/* Report Metrics */
	RTM_LOSING	= 0x5,	/* Kernel Suspects Partitioning */
	RTM_REDIRECT	= 0x6,	/* Told to use different route */
	RTM_MISS	= 0x7,	/* Lookup failed on this address */
	RTM_LOCK	= 0x8,	/* fix specified metrics */
	RTM_OLDADD	= 0x9,	/* caused by SIOCADDRT */
	RTM_OLDDEL	= 0xa,	/* caused by SIOCDELRT */
	RTM_RESOLVE	= 0xb,	/* req to resolve dst to LL addr */
	RTM_NEWADDR	= 0xc,	/* address being added to iface */
	RTM_DELADDR	= 0xd,	/* address being removed from iface */
	RTM_IFINFO	= 0xe,	/* iface going up/down etc. */
	RTM_NEWMADDR	= 0xf,	/* mcast group membership being added to if */
	RTM_DELMADDR	= 0x10,	/* mcast group membership being deleted */
	
	RTM_IFINFO2	= 0x12,	/* */
	RTM_NEWMADDR2	= 0x13,	/* */
	RTM_GET2	= 0x14	/* */
}

/*
 * Bitmask values for rtm_inits and rmx_locks.
 */
enum {
	RTV_MTU		= 0x1,	/* init or lock _mtu */
	RTV_HOPCOUNT	= 0x2,	/* init or lock _hopcount */
	RTV_EXPIRE	= 0x4,	/* init or lock _expire */
	RTV_RPIPE	= 0x8,	/* init or lock _recvpipe */
	RTV_SPIPE	= 0x10,	/* init or lock _sendpipe */
	RTV_SSTHRESH	= 0x20,	/* init or lock _ssthresh */
	RTV_RTT		= 0x40,	/* init or lock _rtt */
	RTV_RTTVAR	= 0x80	/* init or lock _rttvar */
}
/*
 * Bitmask values for rtm_addrs.
 */
enum {
	RTA_DST		= 0x1,	/* destination sockaddr present */
	RTA_GATEWAY	= 0x2,	/* gateway sockaddr present */
	RTA_NETMASK	= 0x4,	/* netmask sockaddr present */
	RTA_GENMASK	= 0x8,	/* cloning mask sockaddr present */
	RTA_IFP		= 0x10,	/* interface name sockaddr present */
	RTA_IFA		= 0x20,	/* interface addr sockaddr present */
	RTA_AUTHOR	= 0x40,	/* sockaddr for author of redirect */
	RTA_BRD		= 0x80	/* for NEWADDR, broadcast or p-p dest addr */
}
/*
 * Index offsets for sockaddr array for alternate internal encoding.
 */
enum {
	RTAX_DST	= 0,	/* destination sockaddr present */
	RTAX_GATEWAY	= 1,	/* gateway sockaddr present */
	RTAX_NETMASK	= 2,	/* netmask sockaddr present */
	RTAX_GENMASK	= 3,	/* cloning mask sockaddr present */
	RTAX_IFP	= 4,	/* interface name sockaddr present */
	RTAX_IFA	= 5,	/* interface addr sockaddr present */
	RTAX_AUTHOR	= 6,	/* sockaddr for author of redirect */
	RTAX_BRD	= 7,	/* for NEWADDR, broadcast or p-p dest addr */
	RTAX_MAX	= 8	/* size of array to allocate */
}

struct rt_addrinfo {
	int	rti_addrs;
	sockaddr*[RTAX_MAX] rti_info;
}

struct route_cb {
	int	ip_count;
	int	ip6_count;
	int	ipx_count;
	int	ns_count;
	int	iso_count;
	int	any_count;
}