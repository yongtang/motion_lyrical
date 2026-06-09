import random
import threading

import rclpy
from pyservicemaker import BatchMetadataOperator, Flow, Pipeline, Probe, RenderMode
from rclpy.executors import SingleThreadedExecutor
from rclpy.node import Node
from sensor_msgs.msg import JointState
from trajectory_msgs.msg import JointTrajectory, JointTrajectoryPoint


class Motion(Node):
    def __init__(self):
        super().__init__("motion_node")

        self._joint_state_ = None
        self._joint_state_lock_ = threading.Lock()

        # Subscribe to /joint_states
        self.create_subscription(
            JointState, "/joint_states", self.subscription_callback, 10
        )

        # Publisher to /joint_trajectory
        self.publisher = self.create_publisher(JointTrajectory, "/joint_trajectory", 10)

    @property
    def joint_state(self):
        with self._joint_state_lock_:
            return self._joint_state_

    @joint_state.setter
    def joint_state(self, value):
        with self._joint_state_lock_:
            self._joint_state_ = value

    def subscription_callback(self, msg: JointState):
        if not msg.name or not msg.position:
            return

        self.joint_state = msg

        # Add random delta [-0.1, 0.1] to each joint
        positions = [p + random.uniform(-0.1, 0.1) for p in msg.position]

        # Construct trajectory message with a single point
        trajectory = JointTrajectory()
        trajectory.joint_names = msg.name
        trajectory.points = [JointTrajectoryPoint()]
        trajectory.points[0].positions = positions
        trajectory.points[0].time_from_start.sec = 0
        trajectory.points[0].time_from_start.nanosec = 500_000_000

        # Publish
        self.publisher.publish(trajectory)
        self.get_logger().info(f"Published trajectory: {trajectory}")


class MotionMetadata(BatchMetadataOperator):
    def __init__(self, motion: Motion):
        super().__init__()
        self.motion = motion

    def handle_metadata(self, batch_meta):
        joint_state = self.motion.joint_state

        if joint_state is None:
            return

        for frame_meta in batch_meta.frame_items:
            print(
                f"frame={frame_meta.frame_number}, "
                f"positions={list(joint_state.position)}"
            )


def main(args=None):
    rclpy.init(args=args)

    node = Motion()

    executor = SingleThreadedExecutor()
    executor.add_node(node)

    thread = threading.Thread(target=executor.spin, daemon=False)
    thread.start()

    try:
        pipeline = Pipeline("motion")

        flow = (
            Flow(pipeline)
            .batch_capture(
                ["/opt/nvidia/deepstream/deepstream/samples/streams/sample_720p.h264"]
            )
            .infer(
                "/opt/nvidia/deepstream/deepstream/"
                "sources/apps/sample_apps/deepstream-test1/"
                "dstest1_pgie_config.yml"
            )
        )

        flow.attach(what=Probe("motion_metadata", MotionMetadata(node))).render(
            mode=RenderMode.DISCARD
        )()

    except KeyboardInterrupt:
        pass

    finally:
        executor.shutdown()
        executor.remove_node(node)
        node.destroy_node()
        rclpy.shutdown()
        thread.join()


if __name__ == "__main__":
    main()
