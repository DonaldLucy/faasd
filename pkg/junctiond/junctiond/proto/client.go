package junctiond

import (
    "context"
    "fmt"

    "google.golang.org/grpc"
    "google.golang.org/grpc/credentials/insecure"
    "google.golang.org/grpc/encoding/gzip"
    "google.golang.org/grpc/metadata"
)

// Client is the high-level Go wrapper around the gRPC JunctionService client.
//
// This mimics how containerd exposes a clean API to faasd, but internally
// forwards all calls to the lower-level protobuf-generated gRPC client.
type Client struct {
    conn   *grpc.ClientConn
    rpc    JunctionServiceClient
}

// New creates a new connection to the junctiond daemon over a Unix socket.
//
// Example:
//    jd, _ := junctiond.New("/run/junctiond.sock")
//    jd.Spawn(ctx, FunctionData{...})
//
func New(sock string) (*Client, error) {
    target := "unix://" + sock

    conn, err := grpc.Dial(
        target,
        grpc.WithTransportCredentials(insecure.NewCredentials()),
        grpc.WithDefaultCallOptions(grpc.UseCompressor(gzip.Name)),
    )
    if err != nil {
        return nil, fmt.Errorf("failed to connect to junctiond at %s: %w", target, err)
    }

    return &Client{
        conn: conn,
        rpc:  NewJunctionServiceClient(conn),
    }, nil
}

// Close closes the TCP/Unix connection to the junctiond daemon.
func (c *Client) Close() error {
    return c.conn.Close()
}

// Spawn creates a new "instance" (container) using the parameters provided.
func (c *Client) Spawn(ctx context.Context, f *FunctionData) error {
    _, err := c.rpc.Spawn(ctx, f)
    return err
}

// Remove stops and cleans up an existing instance by name.
func (c *Client) Remove(ctx context.Context, name string) error {
    req := &FunctionName{Name: name}
    _, err := c.rpc.Remove(ctx, req)
    return err
}

// List returns a list of running instances on the junctiond daemon.
func (c *Client) List(ctx context.Context) ([]*FunctionStatus, error) {
    resp, err := c.rpc.List(ctx, &Empty{})
    if err != nil {
        return nil, err
    }
    return resp.Functions, nil
}
