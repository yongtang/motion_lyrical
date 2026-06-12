import random

import rclpy
from rclpy.node import Node
from sensor_msgs.msg import JointState
from trajectory_msgs.msg import JointTrajectory, JointTrajectoryPoint


class Motion(Node):
    def __init__(self):
        super().__init__("motion_node")

        # Subscribe to /joint_states
        self.create_subscription(
            JointState, "/joint_states", self.subscription_callback, 10
        )

        # Publisher to /joint_trajectory
        self.publisher = self.create_publisher(JointTrajectory, "/joint_trajectory", 10)

    def subscription_callback(self, msg: JointState):
        if not msg.name or not msg.position:
            return

        # Add random delta [-0.1, 0.1] to each joint
        positions = [p + random.uniform(-0.1, 0.1) for p in msg.position]

        # Construct trajectory message with a single point
        trajectory = JointTrajectory()
        trajectory.joint_names = msg.name
        trajectory.points = [JointTrajectoryPoint()]  # single point
        trajectory.points[0].positions = positions
        trajectory.points[0].time_from_start.sec = 0
        trajectory.points[0].time_from_start.nanosec = 500_000_000  # 0.5 seconds

        # Publish
        self.publisher.publish(trajectory)
        self.get_logger().info(f"Published trajectory: {trajectory}")


def main(args=None):
    rclpy.init(args=args)
    node = Motion()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
