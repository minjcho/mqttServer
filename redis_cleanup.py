#!/usr/bin/env python3
"""
Redis 메시지 정리 스크립트
주기적으로 오래된 메시지를 삭제하여 WebSocket 성능 향상
"""

import redis
import time
import logging
import os

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def cleanup_old_messages(redis_client, keep_count=50):
    """최신 메시지만 유지하고 나머지 삭제"""
    try:
        # 모든 메시지 키 가져오기
        keys = redis_client.keys("message:mqtt-messages:*")
        
        if len(keys) <= keep_count:
            logger.info(f"메시지 수 {len(keys)}개, 정리 불필요")
            return
        
        # 오프셋 순으로 정렬
        sorted_keys = sorted(keys, key=lambda x: int(x.decode().split(':')[-1]))
        
        # 오래된 메시지 삭제 (최신 keep_count개만 유지)
        old_keys = sorted_keys[:-keep_count]
        
        if old_keys:
            deleted = redis_client.delete(*old_keys)
            logger.info(f"🧹 {deleted}개 오래된 메시지 삭제, {keep_count}개 최신 메시지 유지")
        
    except Exception as e:
        logger.error(f"정리 중 오류: {e}")

def main():
    # Redis 연결
    redis_host = os.getenv('REDIS_HOST', 'localhost')
    redis_port = int(os.getenv('REDIS_PORT', '6379'))
    
    try:
        redis_client = redis.Redis(
            host=redis_host,
            port=redis_port,
            db=0,
            decode_responses=False
        )
        redis_client.ping()
        logger.info(f"✅ Redis 연결 성공: {redis_host}:{redis_port}")
        
    except Exception as e:
        logger.error(f"❌ Redis 연결 실패: {e}")
        return
    
    logger.info("🚀 Redis 정리 서비스 시작 (30초마다 정리)")
    
    try:
        while True:
            cleanup_old_messages(redis_client, keep_count=20)
            time.sleep(30)  # 30초마다 정리
            
    except KeyboardInterrupt:
        logger.info("👋 정리 서비스 중단")
    except Exception as e:
        logger.error(f"❌ 서비스 오류: {e}")

if __name__ == "__main__":
    main()